import std.stdio;
import std.path;
import std.file;
import std.exception;

import isfreedesktop;
import icontheme;

int main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <icontheme>", args[0]);
        return 0;
    }
    
    string themePath = args[1];
    
    try {
        IconThemeFile iconTheme;
        
        if (themePath.isAbsolute() && themePath.exists) {
            if (themePath.isDir) {
                themePath = buildPath(themePath, "index.theme");
            }
            iconTheme = new IconThemeFile(themePath);
        } else {
            static if (isFreedesktop) {
                iconTheme = openIconTheme(themePath, baseIconDirs());
            }
            if (!iconTheme) {
                throw new Exception("Could not find theme");
            }
            
        }
        
        writeln("Path: ", iconTheme.fileName);
        writeln("Internal name: ", iconTheme.internalName);
        writeln("Name: ", iconTheme.displayName);
        writeln("Comment: ", iconTheme.comment);
        writeln("Is hidden: ", iconTheme.hidden);
        writeln("Subdirectories: ", iconTheme.directories);
        writeln("Inherits: ", iconTheme.inherits());
        writeln("Example: ", iconTheme.example());
    }
    catch(Exception e) {
        stderr.writefln("Error occured: %s", e.msg);
        return 1;
    }
    
    return 0;
}
