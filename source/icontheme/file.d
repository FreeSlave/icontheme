/**
 * This module provides class for reading and accessing icon theme descriptions.
 * 
 * Information about icon themes is stored in special files named index.theme and located in icon theme directory.
 * 
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * See_Also: 
 *  $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html, Icon Theme Specification)
 */

module icontheme.file;

package
{
    import std.algorithm;
    import std.array;
    import std.conv;
    import std.exception;
    import std.path;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
    
    static if( __VERSION__ < 2066 ) enum nogc = 1;
}

import icontheme.cache;

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
     * Returns: The value associated with "Type" key or Type.Threshold if not specified. 
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

final class IconThemeGroup : IniLikeGroup
{
    protected @nogc @safe this() nothrow {
        super("Icon Theme");
    }
    
    /**
     * Short name of the icon theme, used in e.g. lists when selecting themes.
     * Returns: The value associated with "Name" key.
     * See_Also: IconThemeFile.internalName, localizedDisplayName
     */
    @nogc @safe string displayName() const nothrow {
        return value("Name");
    }
    ///Returns: Localized name of icon theme.
    @safe string localizedDisplayName(string locale) const nothrow {
        return localizedValue("Name", locale);
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
     * List of subdirectories for this theme.
     * Returns: The range of multiple values associated with "Directories" key.
     */
    @safe auto directories() const {
        return IconThemeFile.splitValues(value("Directories"));
    }
    
    /**
     * Names of themes that this theme inherits from.
     * Returns: The range of multiple values associated with "Inherits" key.
     * Note: It does NOT automatically adds hicolor theme if it's missing.
     */
    @safe auto inherits() const {
        return IconThemeFile.splitValues(value("Inherits"));
    }
    
protected:
    @trusted override void validateKeyValue(string key, string value) const {
        enforce(isValidKey(key), "key is invalid");
    }
}

/**
 * Class representation of index.theme file containing an icon theme description.
 */
final class IconThemeFile : IniLikeFile
{
    ///Flags to manage icon theme file reading
    enum ReadOptions
    {
        noOptions = 0,              /// Read all groups, skip comments and empty lines, stop on any error.
        preserveComments = 2,       /// Preserve comments and empty lines. Use this when you want to keep them across writing.
        ignoreGroupDuplicates = 4,  /// Ignore group duplicates. The first found will be used.
        ignoreInvalidKeys = 8,      /// Skip invalid keys during parsing.
        ignoreKeyDuplicates = 16,   /// Ignore key duplicates. The first found will be used.
        ignoreUnknownGroups = 32,   /// Don't throw on unknown groups. Still save them.
        skipUnknownGroups = 64,     /// Don't save unknown groups. Use it with ignoreUnknownGroups.
        skipExtensionGroups = 128   /// Skip groups started with X-.
    }
    
    /**
     * Default options for desktop file reading.
     */
    enum defaultReadOptions = ReadOptions.ignoreUnknownGroups | ReadOptions.skipUnknownGroups | ReadOptions.preserveComments;

protected:
    @trusted bool isDirectoryName(string groupName)
    {
        return groupName.pathSplitter.all!isValidFilename;
    }
    
    @trusted override void addCommentForGroup(string comment, IniLikeGroup currentGroup, string groupName)
    {
        if (currentGroup && (_options & ReadOptions.preserveComments)) {
            currentGroup.addComment(comment);
        }
    }
    
    @trusted override void addKeyValueForGroup(string key, string value, IniLikeGroup currentGroup, string groupName)
    {
        if (currentGroup) {
            if ((groupName == "Icon Theme" || isDirectoryName(groupName)) && !isValidKey(key) && (_options & ReadOptions.ignoreInvalidKeys)) {
                return;
            }
            if (currentGroup.contains(key)) {
                if (_options & ReadOptions.ignoreKeyDuplicates) {
                    return;
                } else {
                    throw new Exception("key already exists");
                }
            }
            currentGroup[key] = value;
        }
    }
    
    @trusted override IniLikeGroup createGroup(string groupName)
    {
        if (group(groupName) !is null) {
            if (_options & ReadOptions.ignoreGroupDuplicates) {
                return null;
            } else {
                throw new Exception("group already exists");
            }
        }
        
        if (groupName == "Icon Theme") {
            _iconTheme = new IconThemeGroup();
            return _iconTheme;
        } else if (groupName.startsWith("X-")) {
            if (_options & ReadOptions.skipExtensionGroups) {
                return null;
            } 
            return createEmptyGroup(groupName);
        } else if (isDirectoryName(groupName)) {
            return createEmptyGroup(groupName);
        } else {
            if (_options & ReadOptions.ignoreUnknownGroups) {
                if (_options & ReadOptions.skipUnknownGroups) {
                    return null;
                } else {
                    return createEmptyGroup(groupName);
                }
            } else {
                throw new Exception("Invalid group name: must be valid path or start with 'X-'");
            }
        }
        
    }
    
public:
    /**
     * Reads icon theme from file.
     * Throws:
     *  $(B ErrnoException) if file could not be opened.
     *  $(B IniLikeException) if error occured while reading the file.
     */
    @safe this(string fileName, ReadOptions options = defaultReadOptions) {
        this(iniLikeFileReader(fileName), fileName, options);
    }
    
    /**
     * Reads icon theme file from range of $(B IniLikeLine)s.
     * Throws:
     *  $(B IniLikeException) if error occured while parsing.
     */
    @trusted this(IniLikeReader)(IniLikeReader reader, ReadOptions options = defaultReadOptions, string fileName = null)
    {
        _options = options;
        super(reader, fileName);
        enforce(_iconTheme !is null, new IniLikeException("No \"Icon Theme\" group", 0));
        _options = ReadOptions.ignoreUnknownGroups | ReadOptions.preserveComments;
    }
    
    @trusted this(IniLikeReader)(IniLikeReader reader, string fileName, ReadOptions options = defaultReadOptions)
    {
        this(reader, options, fileName);
    }
    
    /**
     * Constructs IconThemeFile with empty "Icon Theme" group.
     */
    @safe this() {
        super();
        addGroup("Icon Theme");
    }
    
    ///
    unittest
    {
        auto df = new IconThemeFile();
        assert(df.iconTheme());
        assert(df.directories().empty);
    }
    
    /**
     * Removes group by name. You can't remove "Icon Theme" group with this function.
     */
    @safe override void removeGroup(string groupName) nothrow {
        if (groupName != "Icon Theme") {
            super.removeGroup(groupName);
        }
    }
    
    @trusted override void addLeadingComment(string line) nothrow {
        if (_options & ReadOptions.preserveComments) {
            super.addLeadingComment(line);
        }
    }
    
    /** 
     * The name of the subdirectory index.theme was loaded from.
     * See_Also: IconThemeGroup.displayName
     */
    @trusted string internalName() const {
        return fileName().absolutePath().dirName().baseName();
    }
    
    /**
     * Some keys can have multiple values, separated by comma. This function helps to parse such kind of strings into the range.
     * Returns: The range of multiple nonempty values.
     * See_Also: joinValues
     */
    @trusted static auto splitValues(string values) {
        return std.algorithm.splitter(values, ',').filter!(s => s.length != 0);
    }
    
    ///
    unittest
    {
        assert(equal(IconThemeFile.splitValues("16x16/actions,16x16/animations,16x16/apps"), ["16x16/actions", "16x16/animations", "16x16/apps"]));
        assert(IconThemeFile.splitValues(",").empty);
        assert(IconThemeFile.splitValues("").empty);
    }
    
    /**
     * Join range of multiple values into a string using comma as separator.
     * If range is empty, then the empty string is returned.
     * See_Also: splitValues
     */
    @trusted static string joinValues(Range)(Range values) if (isInputRange!Range && isSomeString!(ElementType!Range)) {
        auto result = values.filter!( s => s.length != 0 ).joiner(",");
        if (result.empty) {
            return string.init;
        } else {
            return text(result);
        }
    }
    
    ///
    unittest
    {
        assert(equal(IconThemeFile.joinValues(["16x16/actions", "16x16/animations", "16x16/apps"]), "16x16/actions,16x16/animations,16x16/apps"));
        assert(IconThemeFile.joinValues([""]).empty);
    }
    
    /**
     * Iterating over subdirectories of icon theme.
     * See_Also: IconThemeGroup.directories
     */
    @trusted auto bySubdir() const {
        return directories().filter!(dir => group(dir) !is null).map!(dir => IconSubDir(group(dir)));
    }
    
    /**
     * Icon Theme group in underlying file.
     * Returns: Instance of "Icon Theme" group.
     * Note: Usually you don't need to call this function since you can rely on alias this.
     */
    @nogc @safe inout(IconThemeGroup) iconTheme() nothrow inout {
        return _iconTheme;
    }
    
    /**
     * This alias allows to call functions related to "Icon Theme" group without need to call iconTheme explicitly.
     */
    alias iconTheme this;
    
    
    
    /**
     * Try to load icon cache. Loaded icon cache will be used on icon lookup.
     * Returns: Loaded IconThemeCache object or null, if cache does not exist or invalid or outdated.
     * Note: This function expects that icon theme has fileName.
     * See_Also: icontheme.cache.IconThemeCache, icontheme.lookup.lookupIcon, cache, unloadCache, cachePath
     */
    @trusted auto tryLoadCache(Flag!"allowOutdated" allowOutdated = Flag!"allowOutdated".no) nothrow
    {
        string path = cachePath();
        
        bool isOutdated = true;
        collectException(IconThemeCache.isOutdated(path), isOutdated);
        
        if (isOutdated && !allowOutdated) {
            return null;
        }
        
        IconThemeCache myCache;
        collectException(new IconThemeCache(path), myCache);
        
        if (myCache !is null) {
            _cache = myCache;
        }
        return myCache;
    }
    
    /**
     * Unset loaded cache.
     */
    @nogc @safe void unloadCache() nothrow {
        _cache = null;
    }
    
    /**
     * Set cache object.
     * See_Also: tryLoadCache, iconTheme.lookup.lookupIcons
     */
    @nogc @safe IconThemeCache cache(IconThemeCache setCache) nothrow {
        _cache = setCache;
        return _cache;
    }
    
    /**
     * The object of loaded cache.
     * Returns: IconThemeCache object loaded via tryLoadCache or set by cache property.
     */
    @nogc @safe inout(IconThemeCache) cache() inout nothrow {
        return _cache;
    }
    
    /**
     * Path of icon theme cache file.
     * Returns: Path to icon-theme.cache of corresponding cache file.
     * Note: This function expects that icon theme has fileName. This function does not check if the cache file exists.
     */
    @trusted string cachePath() const nothrow {
        auto f = fileName();
        if (f.length) {
            return buildPath(fileName().dirName, "icon-theme.cache");
        } else {
            return null;
        }
    }
    
private:
    ReadOptions _options;
    IconThemeGroup _iconTheme;
    IconThemeCache _cache;
}

///
unittest
{
    string contents =
`# First comment
[Icon Theme]
Name=Hicolor
Name[ru]=Стандартная тема
Comment=Fallback icon theme
Comment[ru]=Резервная тема
Hidden=true
Directories=16x16/actions,32x32/animations,scalable/emblems
Example=folder
Inherits=gnome,hicolor

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
Type=Scalable

# Will not be saved.
[X-NoName]
Key=Value`;

    string path = buildPath(".", "test", "index.theme");

    auto iconTheme = new IconThemeFile(iniLikeStringReader(contents), path, 
                                       IconThemeFile.ReadOptions.skipExtensionGroups|IconThemeFile.ReadOptions.preserveComments);
    assert(equal(iconTheme.leadingComments(), ["# First comment"]));
    assert(iconTheme.displayName() == "Hicolor");
    assert(iconTheme.localizedDisplayName("ru") == "Стандартная тема");
    assert(iconTheme.comment() == "Fallback icon theme");
    assert(iconTheme.localizedComment("ru") == "Резервная тема");
    assert(iconTheme.hidden());
    assert(equal(iconTheme.directories(), ["16x16/actions", "32x32/animations", "scalable/emblems"]));
    assert(equal(iconTheme.inherits(), ["gnome", "hicolor"]));
    assert(iconTheme.internalName() == "test");
    assert(iconTheme.example() == "folder");
    assert(iconTheme.group("X-NoName") is null);
    
    iconTheme.removeGroup("Icon Theme");
    assert(iconTheme.group("Icon Theme") !is null);
    
    assert(iconTheme.cachePath() == buildPath(".", "test", "icon-theme.cache"));
    
    assert(equal(iconTheme.bySubdir().map!(subdir => tuple(subdir.name(), subdir.size(), subdir.minSize(), subdir.maxSize(), subdir.context(), subdir.type() )), 
                 [tuple("16x16/actions", 16, 16, 16, "Actions", IconSubDir.Type.Threshold), 
                 tuple("32x32/animations", 32, 32, 32, "Animations", IconSubDir.Type.Fixed), 
                 tuple("scalable/emblems", 64, 8, 512, "Emblems", IconSubDir.Type.Scalable)]));
    
    string cachePath = iconTheme.cachePath();
    assert(cachePath.exists);
    
    auto cache = new IconThemeCache(cachePath);
    
    assert(iconTheme.cache is null);
    iconTheme.cache = cache;
    assert(iconTheme.cache is cache);
    iconTheme.unloadCache();
    assert(iconTheme.cache is null);
    
    assert(iconTheme.tryLoadCache(Flag!"allowOutdated".yes));
    
    iconTheme.removeGroup("scalable/emblems");
    assert(iconTheme.group("scalable/emblems") is null);
    
    contents = 
`[Icon Theme]
Name=Theme
[/invalid group]
$=StrangeKey`;

    iconTheme = new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.ignoreUnknownGroups);
    assert(iconTheme.group("/invalid group") !is null);
    assert(iconTheme.group("/invalid group").value("$") == "StrangeKey");
    
    contents = 
`[X-SomeGroup]
Key=Value`;

    auto thrown = collectException!IniLikeException(new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.noOptions));
    assert(thrown !is null);
    assert(thrown.lineNumber == 0);
    
    contents = 
`[Icon Theme]
Valid=Key
$=Invalid`;

    assertThrown(new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.noOptions));
    assertNotThrown(new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.ignoreInvalidKeys));
    
    contents = 
`[Icon Theme]
Key=Value1
Key=Value2`;

    assertThrown(new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.noOptions));
    assertNotThrown(iconTheme = new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.ignoreKeyDuplicates));
    assert(iconTheme.iconTheme().value("Key") == "Value1");
    
    contents = 
`[Icon Theme]
Name=Name
[/invalidpath]
Key=Value`;

    assertThrown(new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.noOptions));
    assertNotThrown(iconTheme = new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.ignoreUnknownGroups));
    assert(iconTheme.cachePath().empty);
    assert(iconTheme.group("/invalidpath") !is null);
    
    iconTheme = new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.ignoreUnknownGroups|IconThemeFile.ReadOptions.skipUnknownGroups);
    assert(iconTheme.group("/invalidpath") is null);
    
    contents = 
`[Icon Theme]
Name=Name1
[Icon Theme]
Name=Name2`;
    
    assertThrown(new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.noOptions));
    assertNotThrown(iconTheme = new IconThemeFile(iniLikeStringReader(contents), IconThemeFile.ReadOptions.ignoreGroupDuplicates));
    
    assert(iconTheme.iconTheme().value("Name") == "Name1");
}
