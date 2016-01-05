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

/**
 * Class representation of index.theme file containing an icon theme description.
 */
final class IconThemeFile : IniLikeFile
{
    alias IniLikeFile.ReadOptions ReadOptions;
    
    package enum defaultReadOptions = ReadOptions.ignoreGroupDuplicates;
    
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
    @trusted this(IniLikeReader)(IniLikeReader reader, string fileName = null, ReadOptions options = defaultReadOptions)
    {   
        super(reader, options, fileName);
        
         _iconTheme = group("Icon Theme");
         enforce(_iconTheme, new IniLikeException("No Icon Theme group", 0));
    }
    
    /**
     * Constructs IconThemeFile with empty "Icon Theme" group.
     */
    @safe this() {
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
     * List of subdirectories for this theme.
     * Returns: The range of multiple values associated with "Directories" key.
     */
    @safe auto directories() const {
        return splitValues(value("Directories"));
    }
    
    /**
     * Names of themes that this theme inherits from.
     * Returns: The range of multiple values associated with "Inherits" key.
     * Note: It does $(B NOT) automatically adds hicolor theme if it's missing.
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
    
    /**
     * Try to load icon cache.
     * Returns: Loaded IconThemeCache object or null, if cache does not exist or invalid or outdated.
     * See_Also: icontheme.cache.IconThemeCache.
     */
    @trusted auto tryLoadCache() nothrow
    {
        string path = cachePath();
        
        bool isOutdated = true;
        collectException(IconThemeCache.isOutdated(path), isOutdated);
        
        if (isOutdated) {
            return null;
        }
        
        IconThemeCache myCache;
        collectException(new IconThemeCache(path), myCache);
        
        if (myCache) {
            _cache = myCache;
            return _cache;
        } else {
            return null;
        }
    }
    
    /**
     * Unset loaded cache.
     */
    @nogc @safe void unloadCache() nothrow {
        _cache = null;
    }
    
    /**
     * Set cache object.
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
     * This function expects that icon theme has fileName.
     * Returns: Path to icon-theme.cache of corresponding cache file.
     * Note: This function does not check if the cache file exists.
     */
    @trusted string cachePath() const nothrow {
        return buildPath(fileName().dirName, "icon-theme.cache");
    }
    
private:
    IniLikeGroup _iconTheme;
    IconThemeCache _cache;
}

///
unittest
{
    string indexThemeContents =
`[Icon Theme]
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
Type=Scalable`;

    string path = "./test/index.theme";

    auto iconTheme = new IconThemeFile(iniLikeStringReader(indexThemeContents), path);
    assert(iconTheme.name() == "Hicolor");
    assert(iconTheme.localizedName("ru") == "Стандартная тема");
    assert(iconTheme.comment() == "Fallback icon theme");
    assert(iconTheme.localizedComment("ru") == "Резервная тема");
    assert(iconTheme.hidden());
    assert(equal(iconTheme.directories(), ["16x16/actions", "32x32/animations", "scalable/emblems"]));
    assert(equal(iconTheme.inherits(), ["gnome", "hicolor"]));
    assert(iconTheme.internalName() == "test");
    assert(iconTheme.example() == "folder");
    
    assert(iconTheme.cachePath() == "./test/icon-theme.cache");
    
    assert(equal(iconTheme.bySubdir().map!(subdir => tuple(subdir.name(), subdir.size(), subdir.minSize(), subdir.maxSize(), subdir.context(), subdir.type() )), 
                 [tuple("16x16/actions", 16, 16, 16, "Actions", IconSubDir.Type.Threshold), 
                 tuple("32x32/animations", 32, 32, 32, "Animations", IconSubDir.Type.Fixed), 
                 tuple("scalable/emblems", 64, 8, 512, "Emblems", IconSubDir.Type.Scalable)]));
    
    string cachePath = iconTheme.cachePath();
    assert(cachePath.exists);
    
    auto cache = new IconThemeCache(cachePath);
    
    assert(iconTheme.cache is null);
    iconTheme.cache = cache;
    assert(iconTheme.cache !is null);
    iconTheme.unloadCache();
    assert(iconTheme.cache is null);
    
    //assert(iconTheme.tryLoadCache() !is null);
}
