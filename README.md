# icontheme

D library for working with icon themes in freedesktop environments. See [Icon Theme Specification](http://standards.freedesktop.org/icon-theme-spec/icon-theme-spec-latest.html).

## Generating documentation

Ddoc:

    dub build --build=docs

Ddox:

    dub build --build=ddox

## Running tests

    dub test

## Examples

### Describe icon theme

Prints the basic information about theme to stdout.

    dub run icontheme:describetheme -- gnome

You also can pass the absolute path to file:

    dub run icontheme:describetheme -- /usr/share/icons/gnome/index.theme

Or directory:

    dub run icontheme:describetheme -- /usr/share/icons/gnome/index.theme

### Icon theme test

Parses all index.theme files in base icon directories. Writes errors (if any) to stderr.
Use this example to check if the icontheme library can parse all themes on your system.

    dub run icontheme:iconthemetest

### Find icon

Utility that finds icon by its name.

    dub run icontheme:findicon -- nautilus

You can also specify theme:

    dub run icontheme:findicon -- --theme=gnome folder

And size:

    dub run icontheme:findicon -- --theme=gnome --size=32 folder


