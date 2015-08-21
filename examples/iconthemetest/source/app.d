import std.stdio;
import icontheme;

void main()
{
    auto searchIconDirs = baseIconDirs();
    debug writeln("Base paths: ", searchIconDirs);
    foreach(path; iconThemePaths(searchIconDirs)) {
        debug writeln(path);
        try {
            new IconThemeFile(path, IconThemeFile.ReadOptions.ignoreGroupDuplicates);
        }
        catch(IniLikeException e) {
            stderr.writefln("Error reading %s: at %s: %s", path, e.lineNumber, e.msg);
        }
        catch(Exception e) {
            stderr.writefln("Error reading %s: %s", path, e.msg);
        }
    }
}
