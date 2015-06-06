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


import inilike;

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
    
    @safe this(const(IniLikeGroup) group) {
        _group = group;
    }
    
    private @nogc @trusted static uint parseSize(string s) nothrow {
        import std.c.stdio : sscanf;
        import std.c.string : strncpy;
        import std.c.stdlib : malloc, free;
        
        if (s.empty) {
            return 0;
        }
        
        char* str = cast(char*)malloc(s.length + 1);
        if (str is null) {
            return 0;
        }
        scope(exit) free(str);
        
        strncpy(str, s.ptr, s.length);
        str[s.length] = '\0';
        
        
        uint result;
        sscanf(str, "%u", &result);
        return result;
    }
    
    /**
     * Nominal size of the icons in this directory.
     * Returns: the value associated with "Size" key converted to an unsigned integer, or 0 if the value is not present or not a number.
     */
    @nogc @safe uint size() const nothrow {
        return parseSize(value("Size"));
    }
    
    /**
     * The context the icon is normally used in.
     * Returns: the value associated with "Context" key.
     */
    @nogc @safe string context() const nothrow {
        return group.value("Context");
    }
    
    /** 
     * The type of icon sizes for the icons in this directory.
     * Returns: the value associated with "Type" key or if not present Type.Threshold is returned. 
     */
    @nogc @safe Type type() const nothrow {
        string t = group.value("Type");
        if (t.length) {
            if (t == "Fixed") {
                return Type.Fixed;
            } else if (t == "Scalable") {
                return Type.Scalable;
            }
        }
        
        return Type.Threshold;
    }
    
    /** 
     * The maximum size that the icons in this directory can be scaled to. Defaults to the value of Size if not present.
     * Returns: the value associated with "MaxSize" key converted to an unsigned integer, or size() if the value is not present or not a number.
     * See_Also: size, minSize
     */
    @nogc @safe uint maxSize() const nothrow {
        uint result = parseSize(value("MaxSize"));
        return result ? result : size();
    }
    
    /** 
     * The minimum size that the icons in this directory can be scaled to. Defaults to the value of Size if not present.
     * Returns: the value associated with "MinSize" key converted to an unsigned integer, or size() if the value is not present or not a number.
     * See_Also: size, maxnSize
     */
    @nogc @safe uint minSize() const nothrow {
        uint result = parseSize(value("MinSize"));
        return result ? result : size();
    }
    
    /**
     * The icons in this directory can be used if the size differ at most this much from the desired size. Defaults to 2 if not present.
     * Returns: the value associated with "Threshold" key, or 2 if the value is not present or not a number.
     */
    @nogc @safe uint threshold() const nothrow {
        string t = group.value("Threshold");
        uint result = parseSize(t);
        return result ? result : 2;
    }
    
    /**
     * Underlying IniLikeGroup instance. 
     * Returns: IniLikeGroup this object was constrcucted from.
     * Note: Usually you don't need to call this function explicitly since you can rely on alias this.
     */
    @nogc @safe const(IniLikeGroup) group() const nothrow {
        return _group;
    }
    
    /**
     * This alias allows to call functions of underlying IniLikeGroup instance.
     */
    alias group this;
    
private:
    const(IniLikeGroup) _group;
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
     *  $(B DesktopFileException) if error occured while reading the file.
     */
    @safe this(string fileName, ReadOptions options = ReadOptions.noOptions) {
        this(iniLikeFileReader(fileName), options, fileName);
    }
    
    /**
     * Reads icon theme file from range of $(B IniLikeLine)s.
     * Throws:
     *  $(B IniLikeException) if error occured while parsing.
     */
    @trusted this(Range)(Range byLine, ReadOptions options = ReadOptions.noOptions, string fileName = null) if(is(ElementType!Range == IniLikeLine))
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
     * Returns: the value associated with "Name" key.
     */
    @nogc @safe string name() const nothrow {
        return value("Name");
    }
    ///ditto, but returns localized value.
    @safe string localizedName(string locale = null) const nothrow {
        return localizedValue("Name", locale);
    }
    
    ///The name of the subdirectory index.theme was loaded from.
    @trusted string internalName() const {
        return fileName().absolutePath().dirName();
    }
    
    /**
     * Longer string describing the theme.
     * Returns: the value associated with "Comment" key.
     */
    @nogc @safe string comment() const nothrow {
        return value("Comment");
    }
    ///ditto, but returns localized value.
    @safe string localizedComment(string locale = null) const nothrow {
        return localizedValue("Comment", locale);
    }
    
    /**
     * Whether to hide the theme in a theme selection user interface.
     * Returns: the value associated with "Hidden" key converted to bool using isTrue.
     */
    @nogc @safe bool hidden() const nothrow {
        return isTrue(value("Hidden"));
    }
    
    /**
     * The name of an icon that should be used as an example of how this theme looks.
     * Returns: the value associated with "Example" key.
     */
    @nogc @safe string example() const nothrow {
        return value("Example");
    }
    
    /**
     * Some keys can have multiple values, separated by comma. This function helps to parse such kind of strings into the range.
     * Returns: the range of multiple nonempty values.
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
     * Returns: the range of multiple values associated with "Directories" key.
     */
    @safe auto directories() const {
        return splitValues(value("Directories"));
    }
    
    /**
     * Names of the themes that this theme inherits from.
     * Returns: the range of multiple values associated with "Inherits" key.
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
     * Returns: instance of "Icon Theme" group.
     * Note: usually you don't need to call this function since you can rely on alias this.
     */
    @nogc @safe inout(IniLikeGroup) iconTheme() nothrow inout {
        return _iconTheme;
    }
    
    /**
     * This alias allows to call functions related to "Desktop Entry" group without need to call desktopEntry explicitly.
     */
    alias iconTheme this;
    
private:
    IniLikeGroup _iconTheme;
}

/**
 * The set of base directories where icon thems should be looked for as described in $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html#directory_layout, Icon Theme Specification)
 */
@safe string[] baseIconDirs() nothrow
{
    @trusted static string[] getDataDirs() nothrow {
        string[] dataDirs;
        collectException(environment.get("XDG_DATA_DIRS").splitter(":").map!(s => buildPath(s, "icons")).array, dataDirs);
        return dataDirs;
    }
    
    string[] toReturn;
    string homePath;
    collectException(environment.get("HOME"), homePath);
    if (homePath.length) {
        toReturn ~= buildPath(homePath, ".icons");
    }
    
    auto dataDirs = getDataDirs();
    if (dataDirs.length) {
        toReturn ~= dataDirs;
    } else {
        toReturn ~= ["/usr/local/share/icons", "/usr/share/icons"];
    }
    toReturn ~= "/usr/share/pixmaps";
    return toReturn;
}

/**
 * The range of paths to index.theme files represented icon themes.
 */
@trusted auto iconThemePaths(Range)(Range searchIconDirs) 
if(is(ElementType!Range == string))
{
    return searchIconDirs
        .filter!(dir => dir.exists && dir.isDir)
        .map!(function(iconDir) {
            return iconDir.dirEntries(SpanMode.shallow)
                .map!(p => buildPath(p, "index.theme"))
                .filter!(function(string f) {
                    bool ok;
                    collectException(f.isFile, ok);
                    return ok;
                });
        })
        .joiner;
}

/**
 * Find index.theme file by theme name.
 */
@trusted auto findIconTheme(Range)(string themeName, Range searchIconDirs) nothrow
if(is(Unqual!(ElementType!Range) == string))
{
    return searchIconDirs
        .map!(dir => buildPath(dir, themeName, "index.theme"))
        .filter!(function(string path) {
            bool ok;
            collectException(path.isFile, ok);
            return ok;
        });
}

/**
 * Create instance of IconThemeFile associated with given theme.
 * Returns: IconThemeFile object corresponding to given theme or null if not found.
 */
@safe IconThemeFile openIconTheme(Range)(string themeName, 
                                         Range searchIconDirs, 
                                         IconThemeFile.ReadOptions options = IconThemeFile.ReadOptions.noOptions)
if(is(Unqual!(ElementType!Range) == string))
{
    auto paths = findIconTheme(themeName, searchIconDirs);
    return paths.empty ? null : new IconThemeFile(paths.front, options);
}

/**
 * Lookup icon alternatives in icon themes.
 * Returns: the range of tuples of found icon file names and corresponding $(B IconSubDir)s
 */
@trusted auto lookupIcon(IconThemes, BaseDirs, Exts)(string iconName, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
if (is(Unqual!(ElementType!IconThemes) == IconThemeFile) && is(Unqual!(ElementType!BaseDirs) == string) && is (Unqual!(ElementType!Exts) == string))
{
    return iconThemes
        .filter!(iconTheme => iconTheme !is null)
        .map!(iconTheme => 
            iconTheme.bySubdir().map!(subdir => 
                searchIconDirs.map!(basePath => 
                    extensions
                        .map!(extension => tuple(buildPath(basePath, iconTheme.internalName(), subdir.name, iconName ~ extension), subdir)  )
                        .filter!(function(pair) {
                            bool ok;
                            collectException(pair[0].isFile, ok);
                            return ok;
                        })
                ).joiner
            ).joiner
        ).joiner;
}

/**
 * Lookup icon alternatives out of icon themes.
 * Returns: the range of found icon file names.
 */
@trusted auto lookupFallbackIcon(BaseDirs, Exts)(string iconName, BaseDirs searchIconDirs, Exts extensions)
if (is(Unqual!(ElementType!BaseDirs) == string) && is (Unqual!(ElementType!Exts) == string))
{
    return 
        searchIconDirs.map!(basePath => 
            extensions
                .map!(extension => buildPath(basePath, iconName ~ extension))
                .filter!(function(string path) {
                    bool ok;
                    collectException(path.isFile, ok);
                    return ok;
                })
        ).joiner;
}

/**
 * Find the icon with best match to given size.
 */
@safe string findIcon(IconThemes, BaseDirs, Exts)(string iconName, uint matchSize, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
{
    string icon = matchBestIcon(lookupIcon(iconName, iconThemes, searchIconDirs, extensions), matchSize);
    if (icon.empty) {
        auto result = lookupFallbackIcon(iconName, searchIconDirs, extensions);
        if (!result.empty) {
            icon = result.front;
        }
    }
    return icon;
}

/**
 * Find the icon with maximum size.
 */
@safe string findIcon(IconThemes, BaseDirs, Exts)(string iconName, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
{
    string icon;
    uint max;
    foreach(t; lookupIcon(iconName, iconThemes, searchIconDirs, extensions)) {
        auto subdir = t[1];
        if (subdir.size() > max) {
            max = subdir.size();
            icon = t[0];
        }
    }
    if (icon.empty) {
        auto result = lookupFallbackIcon(iconName, searchIconDirs, extensions);
        if (!result.empty) {
            icon = result.front;
        }
    }
    return icon;
}

@nogc @safe uint iconSizeDistance(const(IconSubDir) subdir, uint matchSize) nothrow
{
    const uint size = subdir.size();
    const uint minSize = subdir.minSize();
    const uint maxSize = subdir.maxSize();
    const uint threshold = subdir.threshold();
    
    final switch(subdir.type()) {
        case IconSubDir.Type.Fixed:
            return size - matchSize;
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
