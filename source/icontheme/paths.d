/**
 * Getting paths where icon themes and icons are stored.
 *
 * Authors:
 *  $(LINK2 https://github.com/FreeSlave, Roman Chistokhodov)
 * Copyright:
 *  Roman Chistokhodov, 2015-2017
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
        this(string env, string newValue) {
            envVar = env;
            envValue = environment.get(env);
            environment[env] = newValue;
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
        auto homeGuard = EnvGuard("HOME", "/home/user");
        auto dataHomeGuard = EnvGuard("XDG_DATA_HOME", "/home/user/data");
        auto dataDirsGuard = EnvGuard("XDG_DATA_DIRS", "/usr/local/data:/usr/data");

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
        auto dataHomeGuard = EnvGuard("XDG_DATA_HOME", "/home/user/data");
        assert(writableIconsPath() == "/home/user/data/icons");
    }

    ///
    enum IconThemeNameDetector
    {
        none = 0,
        fallback = 1, /// Use hardcoded fallback to detect icon theme name depending on the current desktop environment. Has the lowest priority.
        gtk2 = 2, /// Use gtk2 settings to detect icon theme name. Has lower priority than gtk3 when using both flags.
        gtk3 = 4, /// Use gtk3 settings to detect icon theme name.
        kde = 8, /// Use kde settings to detect icon theme name when the current desktop is KDE4 or KDE5. Has the highest priority when using with other flags.
        automatic =  fallback | gtk2 | gtk3 | kde /// Use all known means to detect icon theme name.
    }

    private @trusted string xdgCurrentDesktop() {
        string currentDesktop;
        collectException(environment.get("XDG_CURRENT_DESKTOP"), currentDesktop);
        return currentDesktop;
    }

    /**
    * Try to detect the current icon name configured by user.
    *
    * $(BLUE This function is Freedesktop only).
    * Note: There's no any specification on that so some heuristics are applied.
    * Another note: It does not check if the icon theme with the detected name really exists on the file system.
    */
    @safe string currentIconThemeName(IconThemeNameDetector detector = IconThemeNameDetector.automatic) nothrow
    {
        @trusted static string fallbackIconThemeName()
        {
            switch(xdgCurrentDesktop()) {
                case "GNOME":
                case "X-Cinnamon":
                case "MATE":
                    return "gnome";
                case "LXDE":
                    return "Adwaita";
                case "XFCE":
                    return "Tango";
                case "KDE":
                    return "oxygen"; //TODO: detect KDE version and set breeze if it's KDE5
                default:
                    return "Tango";
            }
        }
        @trusted static string gtk2IconThemeName()
        {
            import std.stdio : File;
            import std.string : stripLeft, stripRight;
            auto home = environment.get("HOME");
            if (!home.length) {
                return null;
            }
            auto gtkConfigs = [buildPath(home, ".gtkrc-2.0"), "/etc/gtk-2.0/gtkrc"];
            foreach(gtkConfig; gtkConfigs) {
                try {
                    auto f = File(gtkConfig, "r");
                    foreach(line; f.byLine()) {
                        auto splitted = line.findSplit("=");
                        splitted[0] = splitted[0].stripRight;
                        if (splitted[0] == "gtk-icon-theme-name") {
                            splitted[2] = splitted[2].stripLeft;
                            if (splitted[2].length > 2 && splitted[2][0] == '"' && splitted[2][$-1] == '"') {
                                return splitted[2][1..$-1].idup;
                            }
                            break;
                        }
                    }
                } catch(Exception e) {
                    continue;
                }
            }
            return null;
        }
        @trusted static string gtk3IconThemeName()
        {
            import inilike.file;
            auto gtkConfigs = [xdgConfigHome("gtk-3.0/settings.ini"), "/etc/gtk-3.0/settings.ini"];
            foreach(gtkConfig; gtkConfigs) {
                try {
                    auto f = new IniLikeFile(gtkConfig, IniLikeFile.ReadOptions(No.preserveComments));
                    auto settings = f.group("Settings");
                    if (settings)
                        return settings.unescapedValue("gtk-icon-theme-name");
                } catch(Exception e) {
                    continue;
                }
            }
            return null;
        }
        @trusted static string kdeIconThemeName()
        {
            import inilike.file;
            import std.conv : to;
            ubyte kdeVersion;
            auto kdeException = collectException(environment.get("KDE_SESSION_VERSION").to!ubyte, kdeVersion);
            if (kdeException) {
                return null;
            }
            if (kdeVersion < 4) {
                return null;
            }
            string[] kdeConfigPaths;
            immutable kdeglobals = "kdeglobals";
            if (kdeVersion >= 5) {
                kdeConfigPaths = xdgAllConfigDirs(kdeglobals);
            } else {
                auto home = environment.get("HOME");
                if (home.length) {
                    kdeConfigPaths ~= buildPath(home, ".kde4", kdeglobals);
                    kdeConfigPaths ~= buildPath(home, ".kde", kdeglobals);
                    kdeConfigPaths ~= "/etc/kde4/kdeglobals";
                }
            }
            foreach(kdeConfigPath; kdeConfigPaths) {
                try {
                    import std.file :exists;
                    auto config = new IniLikeFile(kdeConfigPath);
                    auto icons = config.group("Icons");
                    if (icons) {
                        auto theme = icons.unescapedValue("Theme");
                        if (theme.length && baseName(theme) == theme) {
                            return theme;
                        }
                    }
                } catch(Exception e) {
                    continue;
                }
            }
            return null;
        }

        try {
            string themeName;
            if (xdgCurrentDesktop() == "KDE" && (detector & IconThemeNameDetector.kde)) {
                collectException(kdeIconThemeName(), themeName);
            }
            if (!themeName.length && (detector & IconThemeNameDetector.gtk3)) {
                collectException(gtk3IconThemeName(), themeName);
            }
            if (!themeName.length && (detector & IconThemeNameDetector.gtk2)) {
                collectException(gtk2IconThemeName(), themeName);
            }
            if (!themeName.length && (detector & IconThemeNameDetector.fallback)) {
                collectException(fallbackIconThemeName(), themeName);
            }
            return themeName;
        } catch(Exception e) {

        }
        return null;
    }

    unittest
    {
        auto desktopGuard = EnvGuard("XDG_CURRENT_DESKTOP", "");
        assert(currentIconThemeName(IconThemeNameDetector.fallback).length);
        assert(currentIconThemeName(IconThemeNameDetector.none).length == 0);
        assert(currentIconThemeName(IconThemeNameDetector.kde).length == 0);

        version(iconthemeFileTest)
        {
            auto homeGuard = EnvGuard("HOME", "./test");
            auto configGuard = EnvGuard("XDG_CONFIG_HOME", "./test");

            assert(currentIconThemeName() == "gnome");
            assert(currentIconThemeName(IconThemeNameDetector.gtk3) == "gnome");
            assert(currentIconThemeName(IconThemeNameDetector.gtk2) == "oxygen");

            {
                auto desktop = EnvGuard("XDG_CURRENT_DESKTOP", "KDE");
                auto kdeVersion = EnvGuard("KDE_SESSION_VERSION", "5");
                assert(currentIconThemeName(IconThemeNameDetector.kde) == "breeze");
            }

            {
                auto desktop = EnvGuard("XDG_CURRENT_DESKTOP", "KDE");
                auto kdeVersion = EnvGuard("KDE_SESSION_VERSION", "4");
                assert(currentIconThemeName(IconThemeNameDetector.kde) == "default.kde4");
            }
        }
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
