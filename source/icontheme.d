/**
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov).
 * Copyright:
 *  Roman Chistokhodov, 2015
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * See_Also: 
 *  $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html, Icon Theme Specification).
 */

module icontheme;

private
{
    import std.stdio;
    import std.process;
    import std.file;
    import std.path;
    import std.string;
    import std.algorithm;
    import std.array;
    import std.range;
    import std.exception;
    import std.conv;

    import std.traits;
    import std.typecons;
    
    static if( __VERSION__ < 2066 ) enum nogc = 1;
}


public import inilike;

/**
 * Adapter of IniLikeGroup for easy access to icon subdirectory properties.
 */
struct IconSubDir
{
    ///The type of icon sizes for the icons in the directory
    enum Type {
        Threshold, 
        Fixed, 
        Scalable
    }
    
    @safe this(const(IniLikeGroup) group) nothrow {
        collectException(group.value("Size").to!uint, _size);
        collectException(group.value("MinSize").to!uint, _minSize);
        collectException(group.value("MaxSize").to!uint, _maxSize);
        
        if (_minSize == 0) {
            _minSize = _size;
        }
        
        if (_maxSize == 0) {
            _maxSize = _size;
        }
        
        collectException(group.value("Threshold").to!uint, _threshold);
        if (_threshold == 0) {
            _threshold = 2;
        }
        
        _type = Type.Threshold;
        
        string t = group.value("Type");
        if (t.length) {
            if (t == "Fixed") {
                _type = Type.Fixed;
            } else if (t == "Scalable") {
                _type = Type.Scalable;
            }
        }
        
        
        _context = group.value("Context");
        _name = group.name();
    }
    
    @safe this(uint size, Type type = Type.Threshold, string context = null, uint minSize = 0, uint maxSize = 0, uint threshold = 2) nothrow pure
    {
        _size = size;
        _context = context;
        _type = type;
        _minSize = minSize ? minSize : size;
        _maxSize = maxSize ? maxSize : size;
        _threshold = threshold;
    }
    
    /**
     * The name of section in icon theme file and relative path to icons.
     */
    @nogc @safe string name() const nothrow pure {
        return _name;
    }
    
    /**
     * Nominal size of the icons in this directory.
     * Returns: The value associated with "Size" key converted to an unsigned integer, or 0 if the value is not present or not a number.
     */
    @nogc @safe uint size() const nothrow pure {
        return _size;
    }
    
    /**
     * The context the icon is normally used in.
     * Returns: The value associated with "Context" key.
     */
    @nogc @safe string context() const nothrow pure {
        return _context;
    }
    
    /** 
     * The type of icon sizes for the icons in this directory.
     * Returns: The value associated with "Type" key or if not present Type.Threshold is returned. 
     */
    @nogc @safe Type type() const nothrow pure {
        return _type;
    }
    
    /** 
     * The maximum size that the icons in this directory can be scaled to. Defaults to the value of Size if not present.
     * Returns: The value associated with "MaxSize" key converted to an unsigned integer, or size() if the value is not present or not a number.
     * See_Also: size, minSize
     */
    @nogc @safe uint maxSize() const nothrow pure {
        return _maxSize;
    }
    
    /** 
     * The minimum size that the icons in this directory can be scaled to. Defaults to the value of Size if not present.
     * Returns: The value associated with "MinSize" key converted to an unsigned integer, or size() if the value is not present or not a number.
     * See_Also: size, maxnSize
     */
    @nogc @safe uint minSize() const nothrow pure {
        return _minSize;
    }
    
    /**
     * The icons in this directory can be used if the size differ at most this much from the desired size. Defaults to 2 if not present.
     * Returns: The value associated with "Threshold" key, or 2 if the value is not present or not a number.
     */
    @nogc @safe uint threshold() const nothrow pure {
        return _threshold;
    }
private:
    uint _size;
    uint _minSize;
    uint _maxSize;
    uint _threshold;
    Type _type;
    string _context;
    string _name;
}

/**
 * Represents index.theme file contained an icon theme.
 */
final class IconThemeFile : IniLikeFile
{
    alias IniLikeFile.ReadOptions ReadOptions;
    
    /**
     * Reads desktop file from file.
     * Throws:
     *  $(B ErrnoException) if file could not be opened.
     *  $(B IniLikeException) if error occured while reading the file.
     */
    @safe this(string fileName, ReadOptions options = ReadOptions.ignoreGroupDuplicates) {
        this(iniLikeFileReader(fileName), options, fileName);
    }
    
    /**
     * Reads icon theme file from range of $(B IniLikeLine)s.
     * Throws:
     *  $(B IniLikeException) if error occured while parsing.
     */
    @trusted this(Range)(Range byLine, ReadOptions options = ReadOptions.ignoreGroupDuplicates, string fileName = null) if(is(ElementType!Range : IniLikeLine))
    {   
        super(byLine, options, fileName);
        
         _iconTheme = group("Icon Theme");
         enforce(_iconTheme, new IniLikeException("no groups", 0));
    }
    
    /**
     * Removes group by name. You can't remove "Icon Theme" group with this function.
     */
    @safe override void removeGroup(string groupName) nothrow {
        if (groupName != "Icon Theme") {
            super.removeGroup(groupName);
        }
    }
    
    /**
     * Create new group using groupName.
     */
    @safe override IniLikeGroup addGroup(string groupName) {
        if (!_iconTheme) {
            enforce(groupName == "Icon Theme", "The first group must be Icon Theme");
            _iconTheme = super.addGroup(groupName);
            return _iconTheme;
        } else {
            return super.addGroup(groupName);
        }
    }
    
    /**
     * Short name of the icon theme, used in e.g. lists when selecting themes.
     * Returns: The value associated with "Name" key.
     */
    @nogc @safe string name() const nothrow {
        return value("Name");
    }
    ///Returns: Localized name of icon theme.
    @safe string localizedName(string locale) const nothrow {
        return localizedValue("Name", locale);
    }
    
    ///The name of the subdirectory index.theme was loaded from.
    @trusted string internalName() const {
        return fileName().absolutePath().dirName().baseName();
    }
    
    /**
     * Longer string describing the theme.
     * Returns: The value associated with "Comment" key.
     */
    @nogc @safe string comment() const nothrow {
        return value("Comment");
    }
    ///Returns: Localized comment.
    @safe string localizedComment(string locale) const nothrow {
        return localizedValue("Comment", locale);
    }
    
    /**
     * Whether to hide the theme in a theme selection user interface.
     * Returns: The value associated with "Hidden" key converted to bool using isTrue.
     */
    @nogc @safe bool hidden() const nothrow {
        return isTrue(value("Hidden"));
    }
    
    /**
     * The name of an icon that should be used as an example of how this theme looks.
     * Returns: The value associated with "Example" key.
     */
    @nogc @safe string example() const nothrow {
        return value("Example");
    }
    
    /**
     * Some keys can have multiple values, separated by comma. This function helps to parse such kind of strings into the range.
     * Returns: The range of multiple nonempty values.
     * See_Also: joinValues
     */
    @trusted static auto splitValues(string values) {
        return values.splitter(',').filter!(s => s.length != 0);
    }
    
    /**
     * Join range of multiple values into a string using comma as separator.
     * If range is empty, then the empty string is returned.
     * See_Also: splitValues
     */
    @trusted static string joinValues(Range)(Range values) if (isInputRange!Range && isSomeString!(ElementType!Range)) {
        auto result = values.filter!( s => s.length != 0 ).joiner(",");
        if (result.empty) {
            return null;
        } else {
            return text(result);
        }
    }
    
    /**
     * List of subdirectories for this theme.
     * Returns: The range of multiple values associated with "Directories" key.
     */
    @safe auto directories() const {
        return splitValues(value("Directories"));
    }
    
    /**
     * Names of the themes that this theme inherits from.
     * Returns: The range of multiple values associated with "Inherits" key.
     */
    @safe auto inherits() const {
        return splitValues(value("Inherits"));
    }
    
    /**
     * Iterating over subdirectories of icon theme.
     */
    @trusted auto bySubdir() const {
        return directories().filter!(dir => group(dir) !is null).map!(dir => IconSubDir(group(dir)));
    }
    
    /**
     * Icon Theme group in underlying file.
     * Returns: Instance of "Icon Theme" group.
     * Note: Usually you don't need to call this function since you can rely on alias this.
     */
    @nogc @safe inout(IniLikeGroup) iconTheme() nothrow inout {
        return _iconTheme;
    }
    
    /**
     * This alias allows to call functions related to "Icon Theme" group without need to call iconTheme explicitly.
     */
    alias iconTheme this;
    
private:
    IniLikeGroup _iconTheme;
}


/**
* The set of base directories where icon thems should be looked for as described in $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html#directory_layout, Icon Theme Specification)
* Note: This function does not provide any caching of its results. This function does not check if directories exist.
* Returns empty array on non-freedesktop systems.
*/
@safe string[] baseIconDirs() nothrow
{
    version(OSX) {
        return null;
    } else version(Posix) {
        @trusted static string[] getDataDirs() nothrow {
            string[] dataDirs;
            collectException(environment.get("XDG_DATA_DIRS").splitter(":").map!(s => buildPath(s, "icons")).array, dataDirs);
            return dataDirs.empty ? ["/usr/local/share/icons", "/usr/share/icons"] : dataDirs;
        }
        
        string[] toReturn;
        string homePath;
        collectException(environment.get("HOME"), homePath);
        if (homePath.length) {
            toReturn ~= buildPath(homePath, ".icons");
        }
        
        string dataHome;
        collectException(environment.get("XDG_DATA_HOME"), dataHome);
        if (dataHome.length) {
            toReturn ~= buildPath(dataHome, "icons");
        } else if (homePath.length) {
            toReturn ~= buildPath(homePath, ".local/share/icons");
        }
        
        toReturn ~= getDataDirs();
        toReturn ~= "/usr/share/pixmaps";
        return toReturn;
    } else {
        return null;
    }
}

/**
 * Find all icon themes in searchIconDirs.
 * Note:
 *  You may want to skip icon themes duplicates if there're different versions of the index.theme file for the same theme.
 * Returns:
 *  Range of paths to index.theme files represented icon themes.
 * Params:
 *  searchIconDirs = base icon directories to search icon themes.
 * See_Also: baseIconDirs
 */
@trusted auto iconThemePaths(Range)(Range searchIconDirs) 
if(is(ElementType!Range : string))
{
    return searchIconDirs
        .filter!(function(dir) { 
            bool ok; 
            collectException(dir.isDir, ok); 
            return ok; 
        }).map!(function(iconDir) {
            return iconDir.dirEntries(SpanMode.shallow)
                .map!(p => buildPath(p, "index.theme")).cache()
                .filter!(function(f) {
                    bool ok;
                    collectException(f.isFile, ok);
                    return ok;
                });
        }).joiner;
}

/**
 * Lookup index.theme files by theme name.
 * Params:
 *  themeName = theme name.
 *  searchIconDirs = base icon directories to search icon themes.
 * Returns:
 *  Range of paths to index.theme file corresponding to the given theme.
 * Note:
 *  Usually you want to use the only first found file.
 * See_Also: baseIconDirs, findIconTheme
 */
@trusted auto lookupIconTheme(Range)(string themeName, Range searchIconDirs)
if(is(ElementType!Range : string))
{
    return searchIconDirs
        .map!(dir => buildPath(dir, themeName, "index.theme")).cache()
        .filter!(function(path) {
            bool ok;
            collectException(path.isFile, ok);
            return ok;
        });
}

/**
 * Find index.theme file by theme name. 
 * Returns:
 *  Path to the first found index.theme file or null string if not found.
 * Params:
 *  themeName = theme name.
 *  searchIconDirs = base icon directories to search icon themes.
 * Returns:
 *  Path to the first found index.theme file corresponding to the given theme.
 * See_Also: baseIconDirs, lookupIconTheme
 */
@trusted auto findIconTheme(Range)(string themeName, Range searchIconDirs)
{
    auto paths = lookupIconTheme(themeName, searchIconDirs);
    if (paths.empty) {
        return null;
    } else {
        return paths.front;
    }
}

/**
 * Find index.theme file for given theme and create instance of IconThemeFile. The first found file will be used.
 * Returns: IconThemeFile object read from the first found index.theme file corresponding to given theme or null if none were found.
 * Params:
 *  themeName = theme name.
 *  searchIconDirs = base icon directories to search icon themes.
 *  options = options for IconThemeFile reading.
 * Throws:
 *  $(B ErrnoException) if file could not be opened.
 *  $(B IniLikeException) if error occured while reading the file.
 * See_Also: findIconTheme, baseIconDirs
 */
@trusted IconThemeFile openIconTheme(Range)(string themeName, 
                                         Range searchIconDirs, 
                                         IconThemeFile.ReadOptions options = IconThemeFile.ReadOptions.ignoreGroupDuplicates)
{
    auto path = findIconTheme(themeName, searchIconDirs);
    return path.empty ? null : new IconThemeFile(to!string(path), options);
}

/**
 * Lookup icon alternatives in icon themes. If searched icon is found in some icon theme all subsequent themes is ignored.
 * Use subdirFilter to filter icons by IconSubDir to decrease the number of searchable items and allocations.
 * Returns: Range of triple tuples of found icon file path, corresponding $(B IconSubDir)s and $(B IconThemeFile).
 * Params:
 *  iconName = icon name.
 *  iconThemes = icon themes to search icon in.
 *  searchIconDirs = base icon directories.
 *  extensions = possible file extensions of needed icon file, in order of preference.
 * Note: Specification says that extension must be ".png", ".xpm" or ".svg", though SVG is not required to be supported. Some icon themes also contain .svgz images.
 * Example:
----------
foreach(item; lookupIcon!(subdir => subdir.context == "Places" && subdir.size >= 32)("folder", iconThemes, baseIconDirs(), [".png", ".xpm"]))
{
    writefln("Icon file: %s. Context: %s. Size: %s. Theme: %s", item[0], item[1].context, item[1].size, item[2].name);
}
----------
 * See_Also: baseIconDirs, lookupFallbackIcon
 */

@trusted auto lookupIcon(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(string iconName, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
if (isInputRange!(IconThemes) && isForwardRange!(BaseDirs) && isForwardRange!(Exts) && 
    is(ElementType!IconThemes : const(IconThemeFile)) && is(ElementType!BaseDirs : string) && is(ElementType!Exts : string))
{
    return iconThemes
        .filter!(iconTheme => iconTheme !is null)
        .map!(iconTheme => 
            iconTheme.bySubdir().filter!(subdirFilter).map!(delegate(subdir) { 
                return searchIconDirs.map!(delegate(basePath) { 
                    auto subdirPath = buildPath(basePath, iconTheme.internalName(), subdir.name);
                    return subdirPath; 
                }).cache().filter!(function(subdirPath) {
                    bool ok;
                    collectException(subdirPath.isDir, ok);
                    return ok;
                }).map!(subdirPath =>
                    extensions
                        .map!(delegate(extension) {
                            auto path = buildPath(subdirPath, iconName ~ extension);
                            return tuple(path, subdir, iconTheme); 
                        }).cache().filter!(function(t) {
                            bool ok;
                            collectException(t[0].isFile, ok);
                            return ok;
                        })
                ).joiner;
            }).joiner
        ).filter!(range => !range.empty).takeOne().joiner;
}

/**
 * Iterate over all icons in icon themes. 
 * iconThemes is usually the range of the main theme and themes it inherits from.
 * Note: Usually if some icon was found in icon theme, it should be ignored in all subsequent themes, including sizes not presented in former theme.
 * Use subdirFilter to filter icons by IconSubDir thus decreasing the number of searchable items and allocations.
 * Returns: Range of triple tuples of found icon file path, corresponding $(B IconSubDir)s and $(B IconThemeFile).
 * Params:
 *  iconThemes = icon themes to search icon in.
 *  searchIconDirs = base icon directories.
 *  extensions = possible file extensions for icon files.
 * Example:
-------------
foreach(item; lookupThemeIcons!(subdir => subdir.context == "MimeTypes" && subdir.size >= 32)(iconThemes, baseIconDirs(), [".png", ".xpm"]))
{
    writefln("Icon file: %s. Context: %s. Size: %s", item[0], item[1].context, item[1].size);
}
-------------
 * See_Also: baseIconDirs, lookupIcon, openBaseThemes
 */

@trusted auto lookupThemeIcons(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions) 
if (is(ElementType!IconThemes : const(IconThemeFile)) && is(ElementType!BaseDirs : string) && is (ElementType!Exts : string))
{
    return iconThemes.filter!(iconTheme => iconTheme !is null).map!(
        iconTheme => iconTheme.bySubdir().filter!(subdirFilter).map!(
            subdir => searchIconDirs.map!(
                basePath => buildPath(basePath, iconTheme.internalName(), subdir.name)
            ).cache().filter!(function(subdirPath) {
                bool ok;
                collectException(subdirPath.isDir, ok);
                return ok;
            }).map!(
                subdirPath => subdirPath.dirEntries(SpanMode.shallow).filter!(
                    filePath => filePath.isFile && extensions.canFind(filePath.extension) 
                ).map!(filePath => tuple(filePath, subdir, iconTheme)).cache()
            ).joiner
        ).joiner
    ).joiner;
}

/**
 * Iterate over all icons out of icon themes. 
 * Returns: Range of found icon file paths.
 * Params:
 *  searchIconDirs = base icon directories.
 *  extensions = possible file extensions for icon files.
 * See_Also:
 *  lookupFallbackIcon, baseIconDirs
 */
@trusted auto lookupFallbackIcons(BaseDirs, Exts)(BaseDirs searchIconDirs, Exts extensions)
if (isForwardRange(searchIconDirs) && isForwardRange(extensions) && 
    isSomeString!(ElementType!BaseDirs) && isSomeString!(ElementType!Exts))
{
    return searchIconDirs.filter!(function(basePath) {
        bool ok;
        collectException(basePath.isDir, ok);
        return ok;
    }).map!(basePath => basePath.dirEntries(SpanMode.shallow).filter!(
        filePath => filePath.isFile && extensions.canFind(filePath.extension)
    )).joiner;
}

/**
 * Lookup icon alternatives beyond the icon themes. May be used as fallback lookup, if lookupIcon returned empty range.
 * Returns: The range of found icon file paths.
 * Example:
----------
auto result = lookupFallbackIcon("folder", baseIconDirs(), [".png", ".xpm"]);
----------
 * See_Also: baseIconDirs, lookupIcon, lookupFallbackIcons
 */
@trusted auto lookupFallbackIcon(BaseDirs, Exts)(string iconName, BaseDirs searchIconDirs, Exts extensions)
if (is(ElementType!BaseDirs : string) && is (ElementType!Exts : string))
{
    return searchIconDirs.map!(basePath => 
        extensions
            .map!(extension => buildPath(basePath, iconName ~ extension)).cache()
            .filter!(function(string path) {
                bool ok;
                collectException(path.isFile, ok);
                return ok;
            })
    ).joiner;
}

/**
 * Find icon of the closest size. The first perfect match is used. If could not find icon in icon themes, uses the first found non-themed fallback.
 * Note: If icon of some size was found in the icon theme, this algorithm does not check following themes, even if they contain icons with closer size. Therefore the icon found in the more preferred theme always has presedence over icons from other themes.
 * See_Also: baseIconDirs, lookupIcon, lookupFallbackIcon
 */
@trusted string findClosestIcon(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(string iconName, uint size, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
{
    uint minDistance = uint.max;
    uint iconDistance = minDistance;
    string closest;
    Rebindable!(ElementType!IconThemes) iconTheme = null;
    
    foreach(t; lookupIcon!(delegate bool(const(IconSubDir) subdir) {
        if (!subdirFilter(subdir)) {
            return false;
        }
        
        uint distance = iconSizeDistance(subdir, size);
        if (distance < minDistance) {
            minDistance = distance;
        }
        return distance <= minDistance;
    })(iconName, iconThemes, searchIconDirs, extensions)) {
        auto path = t[0];
        auto subdir = t[1];
        auto theme = t[2];
        iconTheme = theme;
        
        uint distance = iconSizeDistance(subdir, size);
        if (distance == 0) {
            return path;
        }
        
        if (distance < iconDistance) {
            iconDistance = minDistance;
            closest = path;
        }
    }
    
    if (closest.empty) {
        return findFallbackIcon(iconName, searchIconDirs, extensions);
    } else {
        return closest;
    }
}


/**
 * Find icon of the largest size. If could not find icon in icon themes, uses the first found non-themed fallback.
 * Note: If icon of some size was found in the icon theme, this algorithm does not check following themes, even if they contain icons with larger size. Therefore the icon found in the most preferred theme always has presedence over icons from other themes.
 * See_Also: baseIconDirs, lookupIcon, lookupFallbackIcon
 */
@trusted string findLargestIcon(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(string iconName, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
{
    uint max = 0;
    uint iconSize = max;
    string largest;
    Rebindable!(ElementType!IconThemes) iconTheme = null;
    
    foreach(t; lookupIcon!(delegate bool(const(IconSubDir) subdir) {
        if (!subdirFilter(subdir)) {
            return false;
        }
        if (subdir.size() > max) {
            max = subdir.size();
        }
        return subdir.size() >= max;
    })(iconName, iconThemes, searchIconDirs, extensions)) {
        auto path = t[0];
        auto subdir = t[1];
        auto theme = t[2];
        iconTheme = theme;
        
        if (subdir.size() > iconSize) {
            iconSize = max;
            largest = path;
        }
    }
    
    if (largest.empty) {
        return findFallbackIcon(iconName, searchIconDirs, extensions);
    } else {
        return largest;
    }
}


/**
 * Find fallback icon outside of icon themes. The first found is returned.
 * See_Also: lookupFallbackIcon, baseIconDirs
 */
@trusted string findFallbackIcon(BaseDirs, Exts)(string iconName, BaseDirs searchIconDirs, Exts extensions)
{
    auto r = lookupFallbackIcon(iconName, searchIconDirs, extensions);
    if (r.empty) {
        return null;
    } else {
        return r.front;
    }
}

/**
 * Distance between desired size and minimum or maximum size value supported by icon theme subdirectory.
 */
@nogc @safe uint iconSizeDistance(in IconSubDir subdir, uint matchSize) nothrow pure
{
    const uint size = subdir.size();
    const uint minSize = subdir.minSize();
    const uint maxSize = subdir.maxSize();
    const uint threshold = subdir.threshold();
    
    final switch(subdir.type()) {
        case IconSubDir.Type.Fixed:
        {
            if (size > matchSize) {
                return size - matchSize;
            } else if (size < matchSize) {
                return matchSize - size;
            } else {
                return 0;
            }
        }
        case IconSubDir.Type.Scalable:
        {
            if (matchSize < minSize) {
                return minSize - matchSize;
            } else if (matchSize > maxSize) {
                return matchSize - maxSize;
            } else {
                return 0;
            }
        }
        case IconSubDir.Type.Threshold:
        {
            if (matchSize < size - threshold) {
                return (size - threshold) - matchSize;
            } else if (matchSize > size + threshold) {
                return matchSize - (size + threshold);
            } else {
                return 0;
            }
        }
    }
}

///
unittest 
{
    auto fixed = IconSubDir(32, IconSubDir.Type.Fixed);
    assert(iconSizeDistance(fixed, fixed.size()) == 0);
    assert(iconSizeDistance(fixed, 30) == 2);
    assert(iconSizeDistance(fixed, 35) == 3);
    
    auto threshold = IconSubDir(32, IconSubDir.Type.Threshold, "", 0, 0, 5);
    assert(iconSizeDistance(threshold, threshold.size()) == 0);
    assert(iconSizeDistance(threshold, threshold.size() - threshold.threshold()) == 0);
    assert(iconSizeDistance(threshold, threshold.size() + threshold.threshold()) == 0);
    assert(iconSizeDistance(threshold, 26) == 1);
    assert(iconSizeDistance(threshold, 39) == 2);
    
    auto scalable = IconSubDir(32, IconSubDir.Type.Scalable, "", 24, 48);
    assert(iconSizeDistance(scalable, scalable.size()) == 0);
    assert(iconSizeDistance(scalable, scalable.minSize()) == 0);
    assert(iconSizeDistance(scalable, scalable.maxSize()) == 0);
    assert(iconSizeDistance(scalable, 20) == 4);
    assert(iconSizeDistance(scalable, 50) == 2);
}

/**
 * Check if matchSize belongs to subdir's size range.
 */
@nogc @safe bool matchIconSize(in IconSubDir subdir, uint matchSize) nothrow pure
{
    const uint size = subdir.size();
    const uint minSize = subdir.minSize();
    const uint maxSize = subdir.maxSize();
    const uint threshold = subdir.threshold();
    
    final switch(subdir.type()) {
        case IconSubDir.Type.Fixed:
            return size == matchSize;
        case IconSubDir.Type.Threshold:
            return matchSize <= (size + threshold) && matchSize >= (size - threshold);
        case IconSubDir.Type.Scalable:
            return matchSize >= minSize && matchSize <= maxSize;
    }
}

///
unittest 
{
    auto fixed = IconSubDir(32, IconSubDir.Type.Fixed);
    assert(matchIconSize(fixed, fixed.size()));
    assert(!matchIconSize(fixed, fixed.size() - 2));
    
    auto threshold = IconSubDir(32, IconSubDir.Type.Threshold, "", 0, 0, 5);
    assert(matchIconSize(threshold, threshold.size() + threshold.threshold()));
    assert(matchIconSize(threshold, threshold.size() - threshold.threshold()));
    assert(!matchIconSize(threshold, threshold.size() + threshold.threshold() + 1));
    assert(!matchIconSize(threshold, threshold.size() - threshold.threshold() - 1));
    
    auto scalable = IconSubDir(32, IconSubDir.Type.Scalable, "", 24, 48);
    assert(matchIconSize(scalable, scalable.minSize()));
    assert(matchIconSize(scalable, scalable.maxSize()));
    assert(!matchIconSize(scalable, scalable.minSize() - 1));
    assert(!matchIconSize(scalable, scalable.maxSize() + 1));
}

/**
 * Find icon closest to the given size among given alternatives.
 * Params:
 *  alternatives = range of tuples of file paths and $(B IconSubDir)s, usually returned by lookupIcon.
 *  matchSize = desired size of icon.
 */
@trusted string matchBestIcon(Range)(Range alternatives, uint matchSize)
{
    uint minDistance = uint.max;
    string closest;
    
    foreach(t; alternatives) {
        auto path = t[0];
        auto subdir = t[1];
        uint distance = iconSizeDistance(subdir, matchSize);
        if (distance < minDistance) {
            minDistance = distance;
            closest = path;
        }
        if (minDistance == 0) {
            return closest;
        }
    }
    
    return closest;
}

private @trusted void openBaseThemesHelper(Range)(ref IconThemeFile[] themes, IconThemeFile iconTheme, 
                                      Range searchIconDirs, 
                                      IconThemeFile.ReadOptions options = IconThemeFile.ReadOptions.ignoreGroupDuplicates)
{
    foreach(name; iconTheme.inherits()) {
        if (!themes.canFind!(function(theme, name) {
            return theme.internalName == name;
        })(name)) {
            try {
                IconThemeFile f = openIconTheme(name, searchIconDirs, options);
                if (f) {
                    themes ~= f;
                    openBaseThemesHelper(themes, f, searchIconDirs, options);
                }
            } catch(Exception e) {
                
            }
        }
    }
}

/**
 * Recursively find all themes the given theme is inherited from.
 * Returns:
 *  Array of unique IconThemeFile objects represented base themes.
 * Note: It lists only explicitly specified themes. It may or may not include hicolor usually used as fallback theme.
 */
@trusted IconThemeFile[] openBaseThemes(Range)(IconThemeFile iconTheme, 
                                      Range searchIconDirs, 
                                      IconThemeFile.ReadOptions options = IconThemeFile.ReadOptions.noOptions)
if(isForwardRange!Range && is(ElementType!Range : string))
{
    IconThemeFile[] themes;
    openBaseThemesHelper(themes, iconTheme, searchIconDirs, options);
    return themes;
}

unittest
{
    assert(equal(IconThemeFile.splitValues("16x16/actions,16x16/animations,16x16/apps"), ["16x16/actions", "16x16/animations", "16x16/apps"]));
    assert(IconThemeFile.splitValues(",").empty);
    assert(equal(IconThemeFile.joinValues(["16x16/actions", "16x16/animations", "16x16/apps"]), "16x16/actions,16x16/animations,16x16/apps"));
    assert(IconThemeFile.joinValues([""]).empty);
    
    string indexThemeContents =
`[Icon Theme]
Name=Hicolor
Name[ru]=Стандартная тема
Comment=Fallback icon theme
Comment[ru]=Резервная тема
Hidden=true
Directories=16x16/actions,32x32/animations,scalable/emblems
Example=folder

[16x16/actions]
Size=16
Context=Actions
Type=Threshold

[32x32/animations]
Size=32
Context=Animations
Type=Fixed

[scalable/emblems]
Context=Emblems
Size=64
MinSize=8
MaxSize=512
Type=Scalable`;

    auto iconTheme = new IconThemeFile(iniLikeStringReader(indexThemeContents));
    assert(iconTheme.name() == "Hicolor");
    assert(iconTheme.localizedName("ru") == "Стандартная тема");
    assert(iconTheme.comment() == "Fallback icon theme");
    assert(iconTheme.localizedComment("ru") == "Резервная тема");
    assert(iconTheme.hidden());
    assert(equal(iconTheme.directories(), ["16x16/actions", "32x32/animations", "scalable/emblems"]));
    assert(iconTheme.example() == "folder");
    
    assert(equal(iconTheme.bySubdir().map!(subdir => tuple(subdir.size(), subdir.minSize(), subdir.maxSize(), subdir.context(), subdir.type() )), 
                 [tuple(16, 16, 16, "Actions", IconSubDir.Type.Threshold), 
                 tuple(32, 32, 32, "Animations", IconSubDir.Type.Fixed), 
                 tuple(64, 8, 512, "Emblems", IconSubDir.Type.Scalable)]));
}
