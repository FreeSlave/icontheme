# Icontheme

D library for dealing with icon themes in freedesktop environments.

[![Build Status](https://travis-ci.org/MyLittleRobo/icontheme.svg?branch=master)](https://travis-ci.org/MyLittleRobo/icontheme) [![Coverage Status](https://coveralls.io/repos/MyLittleRobo/icontheme/badge.svg?branch=master&service=github)](https://coveralls.io/github/MyLittleRobo/icontheme?branch=master)

[Online documentation](https://mylittlerobo.github.io/d-freedesktop/docs/icontheme.html)

The most of desktop environments on GNU/Linux and BSD flavors follow [Icon Theme Specification](http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html) when searching for icons.
The goal of **icontheme** library is to provide implementation of this specification in D programming language.
Please feel free to propose enchancements or report any related bugs to *Issues* page.

## Platform support

The library is crossplatform for the most part, though there's little sense to use it on systems that don't follow freedesktop specifications.
**icontheme** is developed and tested on FreeBSD and Debian GNU/Linux.

## Features

### Implemented features

**icontheme** provides all basic operations to deal with icon themes and icon lookup:

* Reading [index.theme](http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html#file_formats) files.
* [Icon lookup](http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html#icon_lookup). Finding the icon file closest to given size.
* Lookup of fallback icons that don't belong to any theme.
* Reading and using icon-theme.cache files. Those are usually generated by [gtk-update-icon-cache](https://developer.gnome.org/gtk3/stable/gtk-update-icon-cache.html). This is not actually the part of specification, but icon caches are quite common nowadays.

### Missing features

Features that currently should be handled by user, but may be implemented in the future versions of library.

* Installing icons to writable path.
* Automatic detection of icon theme currently used in system. This is separate task though and desktop environment dependent.
* Some features regarding icon theme caches are missing, because I could not find specification on this topic.

## Brief

```d
import std.array;
import std.exception;
import std.stdio;

import icontheme;

try {
    string[] searchIconDirs = baseIconDirs(); // Base directories to search themes and icons
    
    // First read icon theme and all related information.
    
    string themeName = ...; // theme name, e.g. "gnome" for GNOME, "oxygen" for KDE4, etc.
    
    IconThemeFile[] iconThemes;
    IconThemeFile iconTheme = openIconTheme(themeName, searchIconDirs); // Read index.theme file contained description if icon theme.
    
    if (iconTheme) {
        writeln("Name: ", iconTheme.name); // Display name of icon theme.
        writeln("Comment: ", iconTheme.comment); // Extended comment on icon theme.
        writeln("Is hidden: ", iconTheme.hidden); // Whether to hide the theme in a theme selection user interface.
        writeln("Subdirectories: ", iconTheme.directories); // Sub directories of icon theme.
        writeln("Inherits: ", iconTheme.inherits()); // Names of themes the main theme inherits from.
        writeln("Example: ", iconTheme.example()); // The name of an icon that should be used as an example of how this theme looks.
        
        iconThemes ~= iconTheme;
        iconThemes ~= openBaseThemes(iconTheme, searchIconDirs); // find and load themes the main theme inherits from.
    } else {
        stderr.writeln("Could not find theme");
    }
    
    foreach(theme; iconThemes) {
        theme.tryLoadCache(); // Use cache on icon lookups.
    }
    
    // Now search for icon by name
    
    // Allowed extensions of image files, in order of preference. Put here extensions that your application supports.
    // Icon Theme Specification requires to support PNG and XPM. SVG support is optional.
    string[] extensions = [".png", ".xpm"];
    
    string iconName = ...; // Some icon name, e.g. "folder" or "edit-copy".
    
    
    // Find largest icon file with such name among given themes and directories.
    string iconPath = findLargestIcon(iconName, iconThemes, searchIconDirs, extensions);
    
    // Or find icon file with size nearest to desired.
    
    size_t size = ...; // Desired icon size.
    iconPath = findClosestIcon(iconName, size, iconThemes, searchIconDirs, extensions); 
    
    // ... load icon from iconPath using preferable image library.
}
catch(IniLikeException e) { // Parsing error - found icon theme file is invalid or can't be read
    stderr.writeln(e.msg);
}

```
    
## Examples

### [Describe icon theme](examples/describetheme/source/app.d)

Prints the basic information about theme to stdout.

    dub run :describe -- gnome
    dub run :describe -- oxygen

You also can pass the absolute path to file:

    dub run :describe -- /usr/share/icons/gnome/index.theme

Or directory:

    dub run :describe -- /usr/share/icons/gnome

### [Icon theme test](examples/iconthemetest/source/app.d)

Parses all found index.theme and icon-theme.cache files in base icon directories. Writes errors (if any) to stderr.
Use this example to check if the icontheme library can parse all themes and theme caches on your system.

    dub run :test

Run to print names of all examined index.theme and icon-theme.cache files to stdout:

    dub run :test -- --verbose
    
### [Find icon](examples/findicon/source/app.d)

Utility that finds icon by its name.
By default search only in hicolor theme:

    dub run :findicon -- nautilus

You can specify additional theme:

    dub run :findicon -- --theme=gnome folder
    dub run :findicon -- --theme=oxygen text-plain

And preferred size:

    dub run :findicon -- --theme=gnome --size=32 folder

Allow using cache:

    dub run :findicon -- --theme=gnome edit-copy --useCache

### [Print icons](examples/printicons/source/app.d)

Search icons in specified theme:

    dub run :print -- --theme=gnome > result.txt

Include hicolor theme, base themes and icons that don't belong to any theme:

    dub run :print -- --include-nonthemed --include-hicolor --include-base --theme=Faenza > result.txt
