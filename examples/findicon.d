/+dub.sdl:
name "findicon"
dependency "icontheme" path="../"
+/

import std.stdio;
import std.getopt;
import std.algorithm;
import std.array;
import std.typecons;

import isfreedesktop;
import icontheme;

int main(string[] args)
{
    string theme;
    uint size;
    string[] baseDirs;
    string extensionsStr;
    bool useCache;
    auto allowNonThemed = Yes.allowNonThemed;

    try {
        getopt(args, "theme", "Icon theme to search icon in. If not set it tries to find fallback.", &theme,
               "size", "Preferred size of icon. If not set it will look for biggest icon.", &size,
               "baseDir", "Base icon path to search themes. This option can be repeated to specify multiple paths.", &baseDirs,
               "extensions", "Possible icon files extensions to search separated by ':'. By default .png and .xpm will be used.", &extensionsStr,
               "useCache", "Use icon theme cache when possible", &useCache,
               "allowNonThemed", "Allow non-themed fallback icon if could not find in themes", &allowNonThemed
              );

        if (args.length < 2) {
            throw new Exception("Icon is not set");
        }


        string iconName = args[1];

        string[] searchIconDirs;
        if (baseDirs.empty) {
            static if (isFreedesktop) {
                searchIconDirs = baseIconDirs();
            }
        } else {
            searchIconDirs = baseDirs;
        }
        if (searchIconDirs.empty) {
            stderr.writeln("No icon theme directories given nor could be detected");
            stderr.writefln("Usage: %s [DIRECTORY]...", args[0]);
            return 1;
        }

        string[] extensions = extensionsStr.empty ? [".png", ".xpm"] : extensionsStr.splitter(':').array;


        debug writefln("Using directories: %-(%s, %)", searchIconDirs);
        debug writeln("Using extensions: ", extensions);

        IconThemeFile[] iconThemes;
        if (!theme.length) {
            theme = currentIconThemeName();
            debug writefln("Icon theme name is not provided in arguments. Evaluated to %s", theme);
        }
        if (theme.length) {
            iconThemes = openThemeFamily(theme, searchIconDirs);
        } else {
            IconThemeFile fallbackTheme = openIconTheme(defaultGenericIconTheme, searchIconDirs);
            if (fallbackTheme) {
                iconThemes ~= fallbackTheme;
            }
        }

        debug writeln("Using icon theme files: ", iconThemes.map!(iconTheme => iconTheme.fileName()));

        if (useCache) {
            foreach(iconTheme; iconThemes) {
                if (iconTheme.tryLoadCache()) {
                    debug writeln("Using icon theme cache for ", iconTheme.internalName());
                }
            }
        }

        string iconPath;
        if (size) {
            iconPath = findClosestIcon(iconName, size, iconThemes, searchIconDirs, extensions, allowNonThemed);
        } else {
            iconPath = findLargestIcon(iconName, iconThemes, searchIconDirs, extensions, allowNonThemed);
        }

        if (iconPath.length) {
            writeln(iconPath);
        } else {
            stderr.writeln("Could not find icon");
            return 1;
        }
    }
    catch (Exception e) {
        stderr.writefln("Error occured: %s", e.msg);
        return 1;
    }
    return 0;
}
