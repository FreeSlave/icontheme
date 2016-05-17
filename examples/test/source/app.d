import std.stdio;
import std.algorithm;
import std.getopt;
import std.file;
import std.range;

import isfreedesktop;
import icontheme;

int main(string[] args)
{
    string[] searchIconDirs;
    bool verbose;
    
    try {
        getopt(args, "verbose", "Print name of each examined file to standard output", &verbose);
    } catch(Exception e) {
        stderr.writeln(e.msg);
        return 1;
    }
    
    
    if (args.length > 1) {
        searchIconDirs = args[1..$];
    } else {
        static if (isFreedesktop) {
            searchIconDirs = baseIconDirs();
        } else version(Windows) {
            import std.process : environment;
            import std.path : buildPath;
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
    
    if (searchIconDirs.empty) {
        stderr.writeln("No icon theme directories given nor could be detected");
        stderr.writefln("Usage: %s [DIRECTORY]...", args[0]);
        return 1;
    }
    
    debug writefln("Using directories: %-(%s, %)", searchIconDirs);
    foreach(path; iconThemePaths(searchIconDirs)) {
        
        IconThemeFile theme;
        string cachePath;
        if (verbose) {
            writeln("Reading icon theme file: ", path);
        }
        try {
            theme = new IconThemeFile(path, IconThemeFile.ReadOptions.noOptions);
        }
        catch(IniLikeReadException e) {
            stderr.writefln("Error reading %s: at %s: %s", path, e.lineNumber, e.msg);
        }
        catch(Exception e) {
            stderr.writefln("Error reading %s: %s", path, e.msg);
        }
        
        try {
            if (theme) {
                cachePath = theme.cachePath;
                if (cachePath.exists) {
                    if (verbose) {
                        writeln("Reading icon theme cache: ", cachePath);
                    }
                    auto cache = new IconThemeCache(cachePath);
                }
            }
        }
        catch(IconThemeCacheException e) {
            stderr.writeln("Error parsing cache file %s: %s", cachePath, e.msg);
        }
        catch(Exception e) {
            stderr.writefln("Error reading %s: %s", cachePath, e.msg);
        }
    }
    
    return 0;
}
