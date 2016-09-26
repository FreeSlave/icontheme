/**
 * Getting paths where icon themes and icons are stored.
 * 
 * Authors: 
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2015-2016
 * License: 
 *  $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * See_Also: 
 *  $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html, Icon Theme Specification)
 */

module icontheme.paths;

private {
    import std.algorithm;
    import std.array;
    import std.exception;
    import std.path;
    import std.range;
    import std.traits;
    import std.process : environment;
    import isfreedesktop;
}

version(unittest) {
    package struct EnvGuard
    {
        this(string env) {
            envVar = env;
            envValue = environment.get(env);
        }
        
        ~this() {
            if (envValue is null) {
                environment.remove(envVar);
            } else {
                environment[envVar] = envValue;
            }
        }
        
        string envVar;
        string envValue;
    }
}


static if (isFreedesktop) {
    import xdgpaths;
    
    /**
    * The list of base directories where icon thems should be looked for as described in $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html#directory_layout, Icon Theme Specification).
    * 
    * $(BLUE This function is Freedesktop only).
    * Note: This function does not provide any caching of its results. This function does not check if directories exist.
    */
    @safe string[] baseIconDirs() nothrow
    {
        string[] toReturn;
        string homePath;
        collectException(environment.get("HOME"), homePath);
        if (homePath.length) {
            toReturn ~= buildPath(homePath, ".icons");
        }
        toReturn ~= xdgAllDataDirs("icons");
        toReturn ~= "/usr/share/pixmaps";
        return toReturn;
    }
    
    ///
    unittest
    {
        auto homeGuard = EnvGuard("HOME");
        auto dataHomeGuard = EnvGuard("XDG_DATA_HOME");
        auto dataDirsGuard = EnvGuard("XDG_DATA_DIRS");
        
        environment["HOME"] = "/home/user";
        environment["XDG_DATA_HOME"] = "/home/user/data";
        environment["XDG_DATA_DIRS"] = "/usr/local/data:/usr/data";
        
        assert(baseIconDirs() == ["/home/user/.icons", "/home/user/data/icons", "/usr/local/data/icons", "/usr/data/icons", "/usr/share/pixmaps"]);
    }
    
    /**
     * Writable base icon path. Depends on XDG_DATA_HOME, so this is $HOME/.local/share/icons rather than $HOME/.icons
     * 
     * $(BLUE This function is Freedesktop only).
     * Note: it does not check if returned path exists and appears to be directory.
     */
    @safe string writableIconsPath() nothrow {
        return xdgDataHome("icons");
    }
    
    ///
    unittest
    {
        auto dataHomeGuard = EnvGuard("XDG_DATA_HOME");
        environment["XDG_DATA_HOME"] = "/home/user/data";
        assert(writableIconsPath() == "/home/user/data/icons");
    }
}

/**
 * The list of icon theme directories based on data paths.
 * Returns: Array of paths with "icons" subdirectory appended to each data path.
 * Note: This function does not check if directories exist.
 */
@trusted string[] baseIconDirs(Range)(Range dataPaths) if (isInputRange!Range && is(ElementType!Range : string))
{
    return dataPaths.map!(p => buildPath(p, "icons")).array;
}

///
unittest
{
    auto dataPaths = ["share", buildPath("local", "share")];
    assert(equal(baseIconDirs(dataPaths), [buildPath("share", "icons"), buildPath("local", "share", "icons")]));
}
