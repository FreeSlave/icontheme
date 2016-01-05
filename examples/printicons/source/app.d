import std.algorithm;
import std.array;
import std.getopt;
import std.stdio;

import icontheme;

int main(string[] args)
{
    bool includeHicolor;
    bool includeNonThemed;
    bool includeBase;
    string theme;
    string[] baseDirs;
    string extensionsStr;
    
    try {
        getopt(args, "theme", "Icon theme to search icon in. If not set it tries to find fallback.", &theme, 
              "baseDir", "Base icon path to search themes. This option can be repeated to specify multiple paths.", &baseDirs,
              "extensions", "Possible icon files extensions to search separated by ':'. By default .png and .xpm will be used.", &extensionsStr,
              "include-hicolor", "Whether to include hicolor theme in results or not. By default false.", &includeHicolor,
              "include-nonthemed", "Whether to print icons out of themes or not. By default false.", &includeNonThemed,
              "include-base", "Whether to include base themes or not. By default false.", &includeBase
              );
        
        string[] searchIconDirs;
        if (baseDirs.empty) {
            version(OSX) {} else version(Posix) {
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
        
        IconThemeFile[] iconThemes;
        if (theme.length) {
            IconThemeFile iconTheme = openIconTheme(theme, searchIconDirs);
            if (iconTheme) {
                iconThemes ~= iconTheme;
                
                if(includeBase) {
                    string fallbackThemeName = includeHicolor ? "hicolor" : string.init;
                    iconThemes ~= openBaseThemes(iconTheme, searchIconDirs, fallbackThemeName);
                }
            }
        } else {
            if (includeHicolor) {
                IconThemeFile fallbackTheme = openIconTheme("hicolor", searchIconDirs);
                if (fallbackTheme) {
                    iconThemes ~= fallbackTheme;
                }
            }
        }
        
        foreach(item; lookupThemeIcons(iconThemes, searchIconDirs, extensions)) {
            if (item[2] is null) {
                writefln("Icon file: %s. Context: %s. Size: %s", item[0], item[1].context, item[1].size);
            } else {
                writefln("Icon file: %s. Context: %s. Size: %s. Theme: %s", item[0], item[1].context, item[1].size, item[2].name);
            }
        }
        
        if (includeNonThemed) {
            writeln("\nNon themed icons:");
            foreach(path; lookupFallbackIcons(searchIconDirs, extensions)) {
                writeln(path);
            }
        }
        
    } catch(Exception e) {
        return 1;
    }
    return 0;
}
