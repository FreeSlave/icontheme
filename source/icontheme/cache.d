/**
 * This module provides class for loading and validating icon theme caches.
 *
 * Icon theme cache may be stored in icon-theme.cache files located in icon theme directory along with index.theme file.
 * These files are usually generated by $(LINK2 https://developer.gnome.org/gtk3/stable/gtk-update-icon-cache.html, gtk-update-icon-cache).
 * Icon theme cache can be used for faster and cheeper lookup of icons since it contains information about which icons exist in which sub directories.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2016
 * License:
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * See_Also:
 *  $(LINK2 https://github.com/GNOME/gtk/blob/master/gtk/gtkiconcachevalidator.c, GTK icon cache validator source code)
 * Note:
 *  I could not find any specification on icon theme cache, so I merely use gtk source code as reference to reimplement parsing of icon-theme.cache files.
 */


module icontheme.cache;

package {
    import std.algorithm;
    import std.bitmanip;
    import std.exception;
    import std.file;
    import std.mmfile;
    import std.path;
    import std.range;
    import std.system;
    import std.typecons;
    import std.traits;

    import std.datetime : SysTime;

    static if( __VERSION__ < 2066 ) enum nogc = 1;
}

private @nogc @trusted void swapByteOrder(T)(ref T t) nothrow pure  {

    static if( __VERSION__ < 2067 ) { //swapEndian was not @nogc
        ubyte[] bytes = (cast(ubyte*)&t)[0..T.sizeof];
        for (size_t i=0; i<bytes.length/2; ++i) {
            ubyte tmp = bytes[i];
            bytes[i] = bytes[T.sizeof-1-i];
            bytes[T.sizeof-1-i] = tmp;
        }
    } else {
        t = swapEndian(t);
    }
}

/**
 * Error occured while parsing icon theme cache.
 */
class IconThemeCacheException : Exception
{
    this(string msg, string context = null, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe {
        super(msg, file, line, next);
        _context = context;
    }

    /**
     * Context where error occured. Usually it's the name of value that could not be read or is invalid.
     */
    @nogc @safe string context() const nothrow {
        return _context;
    }
private:
    string _context;
}

/**
 * Class representation of icon-theme.cache file contained icon theme cache.
 */
final class IconThemeCache
{
    /**
     * Read icon theme cache from memory mapped file and validate it.
     * Throws:
     *  $(B FileException) if could mmap file.
     *  $(D IconThemeCacheException) if icon theme file is invalid.
     */
    @trusted this(string fileName) {
        _mmapped = new MmFile(fileName);
        this(_mmapped[], fileName, 0);
    }

    /**
     * Read icon theme cache from data and validate it.
     * Throws:
     *  $(D IconThemeCacheException) if icon theme file is invalid.
     */
    @safe this(immutable(void)[] data, string fileName) {
        this(data, fileName, 0);
    }

    private @trusted this(const(void)[] data, string fileName, int /* To avoid ambiguity */) {
        _data = data;
        _fileName = fileName;

        _header.majorVersion = readValue!ushort(0, "major version");
        if (_header.majorVersion != 1) {
            throw new IconThemeCacheException("Unsupported version or the file is not icon theme cache", "major version");
        }

        _header.minorVersion = readValue!ushort(2, "minor version");
        if (_header.minorVersion != 0) {
            throw new IconThemeCacheException("Unsupported version or the file is not icon theme cache", "minor version");
        }

        _header.hashOffset = readValue!uint(4, "hash offset");
        _header.directoryListOffset = readValue!uint(8, "directory list offset");

        _bucketCount = iconOffsets().length;
        _directoryCount = directories().length;

        //Validate other data
        foreach(dir; directories()) {
            //pass
        }

        foreach(info; iconInfos) {
            foreach(im; imageInfos(info.imageListOffset)) {

            }
        }
    }

    /**
     * Sub directories of icon theme listed in cache.
     * Returns: Range of directory const(char)[] names listed in cache.
     */
    @trusted auto directories() const {
        auto directoryCount = readValue!uint(_header.directoryListOffset, "directory count");

        return iota(directoryCount)
                .map!(i => _header.directoryListOffset + uint.sizeof + i*uint.sizeof)
                .map!(offset => readValue!uint(offset, "directory offset"))
                .map!(offset => readString(offset, "directory name"));
    }

    /**
     * Test if icon is listed in cache.
     */
    @trusted bool containsIcon(const(char)[] iconName) const
    {
        IconInfo info;
        return findIconInfo(info, iconName);
    }

    /**
     * Test if icon is listed in cache and belongs to specified subdirectory.
     */
    @trusted bool containsIcon(const(char)[] iconName, const(char)[] directory) const {
        auto index = iconDirectories(iconName).countUntil(directory);
        return index != -1;
    }

    /**
     * Find all sub directories the icon belongs to according to cache.
     * Returns: Range of directory const(char)[] names the icon belongs to.
     */
    @trusted auto iconDirectories(const(char)[] iconName) const
    {
        IconInfo info;
        auto dirs = directories();
        bool found = findIconInfo(info, iconName);
        return imageInfos(info.imageListOffset, found).map!(delegate(ImageInfo im) {
            if (im.index < dirs.length) {
                return dirs[im.index];
            } else {
                throw new IconThemeCacheException("Invalid directory index", "directory index");
            }
        });
    }

    /**
     * Path of cache file.
     */
    @nogc @safe fileName() const nothrow {
        return _fileName;
    }

    /**
     * Test if icon theme file is outdated, i.e. modification time of cache file is older than modification time of icon theme directory.
     * Throws:
     *  $(B FileException) on error accessing the file.
     */
    @trusted bool isOutdated() const {
        return isOutdated(fileName());
    }

    /**
     * Test if icon theme file is outdated, i.e. modification time of cache file is older than modification time of icon theme directory.
     *
     * This function is static and therefore can be used before actual reading and validating cache file.
     * Throws:
     *  $(B FileException) on error accessing the file.
     */
    static @trusted bool isOutdated(string fileName)
    {
        if (fileName.empty) {
            throw new FileException("File name is empty, can't check if the cache is outdated");
        }

        SysTime pathAccessTime, pathModificationTime;
        SysTime fileAccessTime, fileModificationTime;

        getTimes(fileName, fileAccessTime, fileModificationTime);
        getTimes(fileName.dirName, pathAccessTime, pathModificationTime);

        return fileModificationTime < pathModificationTime;
    }

    unittest
    {
        assertThrown!FileException(isOutdated(""));
    }

    /**
     * All icon names listed in cache.
     * Returns: Range of icon const(char)[] names listed in cache.
     */
    @trusted auto icons() const {
        return iconInfos().map!(info => info.name);
    }

private:
    alias Tuple!(uint, "chainOffset", const(char)[], "name", uint, "imageListOffset") IconInfo;
    alias Tuple!(ushort, "index", ushort, "flags", uint, "dataOffset") ImageInfo;

    static struct IconThemeCacheHeader
    {
        ushort majorVersion;
        ushort minorVersion;
        uint hashOffset;
        uint directoryListOffset;
    }

    @trusted auto iconInfos() const {
        import std.typecons;

        static struct IconInfos
        {
            this(const(IconThemeCache) cache)
            {
                _cache = rebindable(cache);
                _iconInfos = _cache.bucketIconInfos();
                _chainOffset = _iconInfos.front().chainOffset;
                _fromChain = false;
            }

            bool empty()
            {
                return _iconInfos.empty;
            }

            auto front()
            {
                if (_fromChain) {
                    auto info = _cache.iconInfo(_chainOffset);
                    return info;
                } else {
                    auto info = _iconInfos.front;
                    return info;
                }
            }

            void popFront()
            {
                if (_fromChain) {
                    auto info = _cache.iconInfo(_chainOffset);
                    if (info.chainOffset != 0xffffffff) {
                        _chainOffset = info.chainOffset;
                    } else {
                        _iconInfos.popFront();
                        _fromChain = false;
                    }
                } else {
                    auto info = _iconInfos.front;
                    if (info.chainOffset != 0xffffffff) {
                        _chainOffset = info.chainOffset;
                        _fromChain = true;
                    } else {
                        _iconInfos.popFront();
                    }
                }
            }

            auto save() const {
                return this;
            }

            uint _chainOffset;
            bool _fromChain;
            typeof(_cache.bucketIconInfos()) _iconInfos;
            Rebindable!(const(IconThemeCache)) _cache;
        }

        return IconInfos(this);
    }

    @nogc @trusted static uint iconNameHash(const(char)[] iconName) pure nothrow
    {
        if (iconName.length == 0) {
            return 0;
        }

        uint h = cast(uint)iconName[0];
        if (h) {
            for (size_t i = 1; i != iconName.length; i++) {
                h = (h << 5) - h + cast(uint)iconName[i];
            }
        }
        return h;
    }

    bool findIconInfo(out IconInfo info, const(char)[] iconName) const {
        uint hash = iconNameHash(iconName) % _bucketCount;
        uint chainOffset = readValue!uint(_header.hashOffset + uint.sizeof + uint.sizeof * hash, "chain offset");

        while(chainOffset != 0xffffffff) {
            auto curInfo = iconInfo(chainOffset);
            if (curInfo.name == iconName) {
                info = curInfo;
                return true;
            }
            chainOffset = curInfo.chainOffset;
        }
        return false;
    }

    @trusted auto bucketIconInfos() const {
        return iconOffsets().filter!(offset => offset != 0xffffffff).map!(offset => iconInfo(offset));
    }

    @trusted auto iconOffsets() const {
        auto bucketCount = readValue!uint(_header.hashOffset, "bucket count");

        return iota(bucketCount)
                .map!(i => _header.hashOffset + uint.sizeof + i*uint.sizeof)
                .map!(offset => readValue!uint(offset, "icon offset"));
    }

    @trusted auto iconInfo(size_t iconOffset) const {
        return IconInfo(
            readValue!uint(iconOffset, "icon chain offset"),
            readString(readValue!uint(iconOffset + uint.sizeof, "icon name offset"), "icon name"),
            readValue!uint(iconOffset + uint.sizeof*2, "image list offset"));
    }

    @trusted auto imageInfos(size_t imageListOffset, bool found = true) const {

        uint imageCount = found ? readValue!uint(imageListOffset, "image count") : 0;
        return iota(imageCount)
                .map!(i => imageListOffset + uint.sizeof + i*(uint.sizeof + ushort.sizeof + ushort.sizeof))
                .map!(offset => ImageInfo(
                            readValue!ushort(offset, "image index"),
                            readValue!ushort(offset + ushort.sizeof, "image flags"),
                            readValue!uint(offset + ushort.sizeof*2, "image data offset"))
                     );
    }

    @trusted T readValue(T)(size_t offset, string context = null) const if (isIntegral!T || isSomeChar!T)
    {
        if (_data.length >= offset + T.sizeof) {
            T value = *(cast(const(T)*)_data[offset..(offset+T.sizeof)].ptr);
            static if (endian == Endian.littleEndian) {
                swapByteOrder(value);
            }
            return value;
        } else {
            throw new IconThemeCacheException("Value is out of bounds", context);
        }
    }

    @trusted auto readString(size_t offset, string context = null) const {
        if (offset > _data.length) {
            throw new IconThemeCacheException("Beginning of string is out of bounds", context);
        }

        auto str = cast(const(char[]))_data[offset.._data.length];

        size_t len = 0;
        while (len<str.length && str[len] != '\0') {
            ++len;
        }
        if (len == str.length) {
            throw new IconThemeCacheException("String is not zero terminated", context);
        }

        return str[0..len];
    }

    IconThemeCacheHeader _header;
    size_t _directoryCount;
    size_t _bucketCount;

    MmFile _mmapped;
    string _fileName;
    const(void)[] _data;
}

///
unittest
{
    string cachePath = "./test/Tango/icon-theme.cache";
    assert(cachePath.exists);

    const(IconThemeCache) cache = new IconThemeCache(cachePath);
    assert(cache.fileName == cachePath);
    assert(cache.containsIcon("folder"));
    assert(cache.containsIcon("folder", "24x24/places"));
    assert(cache.containsIcon("edit-copy", "32x32/actions"));
    assert(cache.iconDirectories("text-x-generic").canFind("32x32/mimetypes"));
    assert(cache.directories().canFind("32x32/devices"));

    auto icons = cache.icons();
    assert(icons.canFind("folder"));
    assert(icons.canFind("text-x-generic"));

    try {
        SysTime pathAccessTime, pathModificationTime;
        SysTime fileAccessTime, fileModificationTime;

        getTimes(cachePath, fileAccessTime, fileModificationTime);
        getTimes(cachePath.dirName, pathAccessTime, pathModificationTime);

        setTimes(cachePath, pathAccessTime, pathModificationTime);
        assert(!IconThemeCache.isOutdated(cachePath));
    }
    catch(Exception e) {
        // some environmental error, just ignore
    }

    try {
        auto fileData = assumeUnique(std.file.read(cachePath));
        assertNotThrown(new IconThemeCache(fileData, cachePath));
    } catch(FileException e) {

    }

    immutable(ubyte)[] data = [0,2,0,0];
    IconThemeCacheException thrown = collectException!IconThemeCacheException(new IconThemeCache(data, cachePath));
    assert(thrown !is null, "Invalid cache must throw");
    assert(thrown.context == "major version");

    data = [0,1,0,1];
    thrown = collectException!IconThemeCacheException(new IconThemeCache(data, cachePath));
    assert(thrown !is null, "Invalid cache must throw");
    assert(thrown.context == "minor version");
}
