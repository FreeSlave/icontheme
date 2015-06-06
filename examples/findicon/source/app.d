import std.stdio;
import std.getopt;
import icontheme;

void main(string[] args)
{
    string theme;
    uint size;
    
    try {
        auto optResult = getopt(args, 
                            "theme", "Icon theme to search icon in. If not set it tries to find fallback.", &theme, 
                            "size", "Preferred size of icon. If not set it will look for biggest icon.", &size);
        
        if (args.length < 2) {
            throw new Exception("Icon is not set");
        }
        
        string iconName = args[1];
        
        string[] extensions = [".png", ".xpm", ".svg"];
        auto readOptions = IconThemeFile.ReadOptions.ignoreGroupDuplicates;
        
        string[] searchIconDirs = baseIconDirs();
        IconThemeFile[] iconThemes = [openIconTheme(theme, searchIconDirs, readOptions), openIconTheme("hicolor", searchIconDirs, readOptions)];
        
        string iconPath;
        if (size) {
            iconPath = findIcon(iconName, size, iconThemes, searchIconDirs, extensions);
        } else {
            iconPath = findIcon(iconName, iconThemes, searchIconDirs, extensions);
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