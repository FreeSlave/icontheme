import std.stdio;
import std.getopt;
import icontheme;
import std.algorithm;
import std.array;

int main(string[] args)
{
    string theme;
    uint size;
    string[] baseDirs;
    string extensionsStr;
    
    try {
        getopt(args, "theme", "Icon theme to search icon in. If not set it tries to find fallback.", &theme, 
               "size", "Preferred size of icon. If not set it will look for biggest icon.", &size,
              "baseDir", "Base icon path to search themes. This option can be repeated to specify multiple paths.", &baseDirs,
              "extensions", "Possible icon files extensions to search separated by ':'. By default .png and .xpm will be used.", &extensionsStr
              );
        
        if (args.length < 2) {
            throw new Exception("Icon is not set");
        }
        
        string iconName = args[1];
        
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
        auto readOptions = IconThemeFile.ReadOptions.ignoreGroupDuplicates;
        
        
        debug writefln("Using directories: %-(%s, %)", searchIconDirs);
        debug writeln("Using extensions: ", extensions);
        
        IconThemeFile[] iconThemes;
        if (theme.length) {
            IconThemeFile iconTheme = openIconTheme(theme, searchIconDirs, readOptions);
            if (iconTheme) {
                iconThemes ~= iconTheme;
                iconThemes ~= openBaseThemes(iconTheme, searchIconDirs, readOptions);
            }
        }
        
        auto hicolorFound = iconThemes.filter!(theme => theme !is null).find!(theme => theme.internalName == "hicolor");
        if (hicolorFound.empty) {
            iconThemes ~= openIconTheme("hicolor", searchIconDirs, readOptions);
        }
        
        debug writeln("Using icon theme files: ", iconThemes.map!(iconTheme => iconTheme.fileName()));
        
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
            return 1;
        }
    }
    catch (Exception e) {
        stderr.writefln("Error occured: %s", e.msg);
        return 1;
    }
    return 0;
}
