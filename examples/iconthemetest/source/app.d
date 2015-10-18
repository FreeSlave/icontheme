import std.stdio;
import std.algorithm;
import std.getopt;
import std.file;
import icontheme;

void main(string[] args)
{
    string[] searchIconDirs;
    bool verbose;
    getopt(args, "verbose", "Print name of each examined index.theme file to standard output", &verbose);
    
    if (args.length > 1) {
        searchIconDirs = args[1..$];
    } else {
        version(OSX) {} else version(Posix) {
            searchIconDirs = baseIconDirs();
        } else version(Windows) {
            try {
                auto root = environment.get("SYSTEMDRIVE", "C:");
                auto kdeDir = root ~ `\ProgramData\KDE\share`;
                if (kdeDir.isDir) {
                    searchIconDirs = [buildPath(kdeDir, `icons`)];
                }
            } catch(Exception e) {
                
            }
        }
    }
    
    if (!searchIconDirs.length) {
        stderr.writeln("No icon directories given nor could be detected");
        stderr.writefln("Usage: %s [DIRECTORY]...", args[0]);
        return;
    }
    
    writefln("Using directories: %-(%s, %)", searchIconDirs);
    foreach(path; iconThemePaths(searchIconDirs)) {
        if (verbose) {
            writeln(path);
        }
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
