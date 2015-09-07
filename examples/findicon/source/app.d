import std.stdio;
import std.getopt;
import icontheme;
import std.algorithm;
import std.array;

void main(string[] args)
{
    string theme;
    uint size;
    string basePathsStr;
    string extensionsStr;
    
    try {
        getopt(args, "theme", "Icon theme to search icon in. If not set it tries to find fallback.", &theme, 
               "size", "Preferred size of icon. If not set it will look for biggest icon.", &size,
              "baseDirs", "Base icon paths to search themes separated by ':'.", &basePathsStr,
              "extensions", "Possible icon files extensions to search separated by ':'. By default .png and .xpm will be used.", &extensionsStr
              );
        
        if (args.length < 2) {
            throw new Exception("Icon is not set");
        }
        
        string iconName = args[1];
        
        string[] searchIconDirs = basePathsStr.empty ? baseIconDirs() : basePathsStr.splitter(':').array;
        string[] extensions = extensionsStr.empty ? [".png", ".xpm"] : extensionsStr.splitter(':').array;
        auto readOptions = IconThemeFile.ReadOptions.ignoreGroupDuplicates;
        
        debug writeln("Base paths: ", searchIconDirs);
        debug writeln("Extensions: ", extensions);
        
        IconThemeFile[] iconThemes;
        if (theme.length) {
            IconThemeFile iconTheme = openIconTheme(theme, searchIconDirs, readOptions);
            if (iconTheme) {
                iconThemes ~= iconTheme;
                iconThemes ~= openBaseThemes(iconTheme, searchIconDirs, readOptions);
            }
        }
        iconThemes ~= openIconTheme("hicolor", searchIconDirs, readOptions);
        
//         foreach(t; lookupIcon(iconName, iconThemes, searchIconDirs, extensions)) {
//             debug writeln(t[0]);
//         }
        
        string iconPath;
        if (size) {
            iconPath = findClosestIcon(iconName, size, iconThemes, searchIconDirs, extensions);
        } else {
            iconPath = findLargestIcon(iconName, iconThemes, searchIconDirs, extensions);
        }
        
        if (iconPath.length) {
            writeln(iconPath);
        } else {
            stderr.writeln("Could not find icon");
        }
    }
    catch (Exception e) {
        stderr.writefln("Error occured: %s", e.msg);
    }
}
