import std.stdio;
import std.path;
import std.file;
import std.exception;
import icontheme;

void main(string[] args)
{
    if (args.length < 2) {
        writeln("Usage: %s <icontheme>", args[0]);
        return;
    }
    
    string themePath = args[1];
    
    try {
        IconThemeFile iconTheme;
        
        if (themePath.isAbsolute()) {
            if (themePath.isDir) {
                themePath = buildPath(themePath, "index.theme");
            }
            iconTheme = new IconThemeFile(themePath, IconThemeFile.ReadOptions.ignoreGroupDuplicates);
        } else {
            iconTheme = enforce(openIconTheme(themePath, baseIconDirs(), IconThemeFile.ReadOptions.ignoreGroupDuplicates), "Could not find theme");
        }
        
        writeln("Path: ", iconTheme.fileName);
        writeln("Internal name: ", iconTheme.internalName);
        writeln("Name: ", iconTheme.name);
        writeln("Comment: ", iconTheme.comment);
        writeln("Is hidden: ", iconTheme.hidden);
        writeln("Subdirectories: ", iconTheme.directories);
    }
    catch(Exception e) {
        stderr.writefln("Error occured: %s", e.msg);
    }
}
