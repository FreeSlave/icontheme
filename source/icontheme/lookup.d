/**
 * Lookup of icon themes and icons.
 * 
 * Note: All found icons are just paths. They are not verified to be valid images.
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

module icontheme.lookup;

import icontheme.file;

package {
    import std.file;
    import std.path;
    import std.range;
    import std.traits;
    import std.typecons;
}

/**
 * Find all icon themes in searchIconDirs.
 * Note:
 *  You may want to skip icon themes duplicates if there're different versions of the index.theme file for the same theme.
 * Returns:
 *  Range of paths to index.theme files represented icon themes.
 * Params:
 *  searchIconDirs = base icon directories to search icon themes.
 * See_Also: icontheme.paths.baseIconDirs
 */
auto iconThemePaths(Range)(Range searchIconDirs) 
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
 * See_Also: icontheme.paths.baseIconDirs, findIconTheme
 */
auto lookupIconTheme(Range)(string themeName, Range searchIconDirs)
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
 *  themeName = Theme name.
 *  searchIconDirs = Base icon directories to search icon themes.
 * Returns:
 *  Path to the first found index.theme file corresponding to the given theme.
 * See_Also: icontheme.paths.baseIconDirs, lookupIconTheme
 */
auto findIconTheme(Range)(string themeName, Range searchIconDirs)
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
 * See_Also: findIconTheme, icontheme.paths.baseIconDirs
 */
IconThemeFile openIconTheme(Range)(string themeName, 
                                         Range searchIconDirs, 
                                         IconThemeFile.ReadOptions options = IconThemeFile.defaultReadOptions)
{
    auto path = findIconTheme(themeName, searchIconDirs);
    return path.empty ? null : new IconThemeFile(to!string(path), options);
}


private auto withExtensions(Tripplet, Exts, IconTheme)(Exts extensions, string iconName, string subdirPath, IconSubDir subdir, IconTheme iconTheme)
if (isForwardRange!(Exts) && is(ElementType!Exts : string) && is(IconTheme : const(IconThemeFile)))
{
    return extensions
            .map!(delegate(extension) {
                auto path = buildPath(subdirPath, iconName ~ extension);
                return Tripplet(path, subdir, iconTheme); 
            }).cache().filter!(function(t) {
                bool ok;
                collectException(t[0].isFile, ok);
                return ok;
            });
}

/**
 * Lookup icon alternatives in icon themes. It uses icon theme cache wherever possible. If searched icon is found in some icon theme all subsequent themes are ignored.
 * 
 * This function may make nearly 2000 calls to stat in one call, so beware. Use subdirFilter to filter icons by IconSubDir properties (e.g. by size or context) to decrease the number of searchable items and allocations. You also may want to filter out nonexistent paths from searchIconDirs before passing it to this function. Loading IconThemeCache may drastically descrease the number of stats.
 * 
 * Returns: Range of triple tuples of found icon file path, corresponding icontheme.file.IconSubDir and icontheme.file.IconThemeFile.
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
    writefln("Icon file: %s. Context: %s. Size: %s. Theme: %s", item[0], item[1].context, item[1].size, item[2].displayName);
}
----------
 * See_Also: icontheme.paths.baseIconDirs, lookupFallbackIcon
 */

auto lookupIcon(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(string iconName, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions)
if (isInputRange!(IconThemes) && isForwardRange!(BaseDirs) && isForwardRange!(Exts) && 
    is(ElementType!IconThemes : const(IconThemeFile)) && is(ElementType!BaseDirs : string) && is(ElementType!Exts : string))
{
    alias Tuple!(string, IconSubDir, ElementType!IconThemes) Tripplet;
    
    return iconThemes
        .filter!(iconTheme => iconTheme !is null)
        .map!(iconTheme => 
            iconTheme.bySubdir().filter!(subdirFilter).map!(delegate(subdir) {
                if (iconTheme.cache !is null) {
                    if (iconTheme.cache.containsIcon(iconName, subdir.name)) {
                        auto subdirPath = buildPath(iconTheme.cache.fileName.dirName, subdir.name);
                        auto r = withExtensions!Tripplet(extensions, iconName, subdirPath, subdir, iconTheme);
                        
                        InputRange!Tripplet iro = inputRangeObject(r);
                        return iro;
                    } else {
                        auto r = withExtensions!Tripplet((string[]).init, iconName, string.init, subdir, iconTheme);
                        InputRange!Tripplet iro = inputRangeObject(r);
                        return iro;
                    }
                } else {
                    auto r = searchIconDirs.map!(delegate(basePath) {
                        auto subdirPath = buildPath(basePath, iconTheme.internalName(), subdir.name);
                        return subdirPath; 
                    }).cache().filter!(function(subdirPath) {
                        bool ok;
                        collectException(subdirPath.isDir, ok);
                        return ok;
                    }).map!(subdirPath => withExtensions!Tripplet(extensions, iconName, subdirPath, subdir, iconTheme)).joiner;
                    InputRange!Tripplet iro = inputRangeObject(r);
                    return iro;
                }
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
 * See_Also: icontheme.paths.baseIconDirs, lookupIcon, openBaseThemes
 */

auto lookupThemeIcons(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions) 
if (is(ElementType!IconThemes : const(IconThemeFile)) && is(ElementType!BaseDirs : string) && is (ElementType!Exts : string))
{
    return iconThemes.filter!(iconTheme => iconTheme !is null).map!(
        iconTheme => iconTheme.bySubdir().filter!(subdirFilter).map!(
            subdir => searchIconDirs.map!(
                basePath => buildPath(basePath, iconTheme.internalName(), subdir.name)
            ).filter!(function(subdirPath) {
                bool ok;
                collectException(subdirPath.isDir, ok);
                return ok;
            }).map!(
                subdirPath => subdirPath.dirEntries(SpanMode.shallow).filter!(
                    filePath => filePath.isFile && extensions.canFind(filePath.extension) 
                ).map!(filePath => tuple(filePath, subdir, iconTheme))
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
 *  lookupFallbackIcon, icontheme.paths.baseIconDirs
 */
auto lookupFallbackIcons(BaseDirs, Exts)(BaseDirs searchIconDirs, Exts extensions)
if (isInputRange!(BaseDirs) && isForwardRange!(Exts) && 
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
 * See_Also: icontheme.paths.baseIconDirs, lookupIcon, lookupFallbackIcons
 */
auto lookupFallbackIcon(BaseDirs, Exts)(string iconName, BaseDirs searchIconDirs, Exts extensions)
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
 * Find icon closest of the size. It uses icon theme cache wherever possible. The first perfect match is used.
 * Params:
 *  iconName = Name of icon to search as defined by Icon Theme Specification (i.e. without path and extension parts).
 *  size = Preferred icon size to get.
 *  iconThemes = Range of icontheme.file.IconThemeFile objects.
 *  searchIconDirs = Base icon directories.
 *  extensions = Allowed file extensions.
 *  allowFallback = Allow searching for non-themed fallback if could not find icon in themes (non-themed icon can be any size).
 * Returns: Icon file path or empty string if not found.
 * Note: If icon of some size was found in the icon theme, this algorithm does not check following themes, even if they contain icons with closer size. Therefore the icon found in the more preferred theme always has presedence over icons from other themes.
 * See_Also: icontheme.paths.baseIconDirs, lookupIcon, findFallbackIcon
 */
string findClosestIcon(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(string iconName, uint size, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions, Flag!"allowFallbackIcon" allowFallback = Yes.allowFallbackIcon)
{
    uint minDistance = uint.max;
    uint iconDistance = minDistance;
    string closest;
    
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
        
        uint distance = iconSizeDistance(subdir, size);
        if (distance == 0) {
            return path;
        }
        
        if (distance < iconDistance) {
            iconDistance = minDistance;
            closest = path;
        }
    }
    
    if (closest.empty && allowFallback) {
        return findFallbackIcon(iconName, searchIconDirs, extensions);
    } else {
        return closest;
    }
}


/**
 * Find icon of the largest size. It uses icon theme cache wherever possible.
 * Params:
 *  iconName = Name of icon to search as defined by Icon Theme Specification (i.e. without path and extension parts).
 *  iconThemes = Range of icontheme.file.IconThemeFile objects.
 *  searchIconDirs = Base icon directories.
 *  extensions = Allowed file extensions.
 *  allowFallback = Allow searching for non-themed fallback if could not find icon in themes.
 * Returns: Icon file path or empty string if not found.
 * Note: If icon of some size was found in the icon theme, this algorithm does not check following themes, even if they contain icons with larger size. Therefore the icon found in the most preferred theme always has presedence over icons from other themes.
 * See_Also: icontheme.paths.baseIconDirs, lookupIcon, findFallbackIcon
 */
string findLargestIcon(alias subdirFilter = (a => true), IconThemes, BaseDirs, Exts)(string iconName, IconThemes iconThemes, BaseDirs searchIconDirs, Exts extensions, Flag!"allowFallbackIcon" allowFallback = Yes.allowFallbackIcon)
{
    uint max = 0;
    uint iconSize = max;
    string largest;
    
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
 * See_Also: lookupFallbackIcon, icontheme.paths.baseIconDirs
 */
string findFallbackIcon(BaseDirs, Exts)(string iconName, BaseDirs searchIconDirs, Exts extensions)
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
string matchBestIcon(Range)(Range alternatives, uint matchSize)
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

private void openBaseThemesHelper(Range)(ref IconThemeFile[] themes, IconThemeFile iconTheme, 
                                      Range searchIconDirs, 
                                      IconThemeFile.ReadOptions options)
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
 * Params:
 *  iconTheme = Original icon theme to search for its base themes. Included as first element in resulting array.
 *  searchIconDirs = Base icon directories to search icon themes.
 *  fallbackThemeName = Name of fallback theme which is loaded the last. Not used if empty. It's NOT loaded twice if some theme in inheritance tree has it as base theme.
 *  options = Options for IconThemeFile reading.
 * Returns:
 *  Array of unique IconThemeFile objects represented base themes.
 */
IconThemeFile[] openBaseThemes(Range)(IconThemeFile iconTheme, 
                                      Range searchIconDirs, 
                                      string fallbackThemeName = "hicolor",
                                      IconThemeFile.ReadOptions options = IconThemeFile.defaultReadOptions)
if(isForwardRange!Range && is(ElementType!Range : string))
{
    IconThemeFile[] themes;
    openBaseThemesHelper(themes, iconTheme, searchIconDirs, options);
    
    if (fallbackThemeName.length) {
        auto fallbackFound = themes.filter!(theme => theme !is null).find!(theme => theme.internalName == fallbackThemeName);
        if (fallbackFound.empty) {
            IconThemeFile fallbackTheme;
            collectException(openIconTheme(fallbackThemeName, searchIconDirs, options), fallbackTheme);
            if (fallbackTheme) {
                themes ~= fallbackTheme;
            }
        }
    }
    
    return themes;
}
