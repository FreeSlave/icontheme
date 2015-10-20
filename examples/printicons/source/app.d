import std.stdio;
import std.getopt;
import icontheme;
import std.algorithm;
import std.array;

int main(string[] args)
{
    bool includeHicolor = true;
    bool includeNonThemed = true;
    bool includeBase = true;
    string theme;
    string basePathsStr;
    string extensionsStr;
    
    try {
        getopt(args, "theme", "Icon theme to search icon in. If not set it tries to find fallback.", &theme, 
              "baseDirs", "Base icon paths to search themes separated by ':'.", &basePathsStr,
              "extensions", "Possible icon files extensions to search separated by ':'. By default .png and .xpm will be used.", &extensionsStr,
              "include-hicolor", "Whether to include hicolor theme in results or not. By default true.", &includeHicolor,
              "include-nonthemed", "Whether to print icons out of themes or not. By default true.", &includeNonThemed,
              "include-base", "Whether to include base themes or not. By default true.", &includeBase
              );
        
        string[] searchIconDirs;
        if (basePathsStr.empty) {
            version(OSX) {} else version(Posix) {
                searchIconDirs = baseIconDirs();
            }
        } else {
            searchIconDirs = basePathsStr.splitter(':').array;
        }
        if (searchIconDirs.empty) {
            stderr.writeln("No icon theme directories given nor could be detected");
            stderr.writefln("Usage: %s [DIRECTORY]...", args[0]);
            return 1;
        }
        
        string[] extensions = extensionsStr.empty ? [".png", ".xpm"] : extensionsStr.splitter(':').array;
        auto readOptions = IconThemeFile.ReadOptions.ignoreGroupDuplicates;
        
        IconThemeFile[] iconThemes;
        if (theme.length) {
            IconThemeFile iconTheme = openIconTheme(theme, searchIconDirs, readOptions);
            if (iconTheme) {
                iconThemes ~= iconTheme;
            }
            if(includeBase) {
                iconThemes ~= openBaseThemes(iconTheme, searchIconDirs, readOptions);
            }
        }
        if (includeHicolor) {
            iconThemes ~= openIconTheme("hicolor", searchIconDirs, readOptions);
        }
        
        foreach(item; lookupThemeIcons(iconThemes, searchIconDirs, extensions)) {
            writefln("Icon file: %s. Context: %s. Size: %s. Theme: %s", item[0], item[1].context, item[1].size, item[2].name);
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
