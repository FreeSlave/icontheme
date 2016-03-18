/**
 * Getting paths where icon themes and icons are stored.
 * 
 * Authors: 
 *  $(LINK2 https://github.com/MyLittleRobo, Roman Chistokhodov)
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
    import std.process : environment;
    import std.range;
    import std.traits;

    import isfreedesktop;
    import xdgpaths;
}


static if (isFreedesktop) {
    /**
    * The list of base directories where icon thems should be looked for as described in $(LINK2 http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html#directory_layout, Icon Theme Specification). Available only on freedesktop systems.
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
