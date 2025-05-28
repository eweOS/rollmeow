# rollmeow

An update checker.

## Installation

### Dependency

- `lua5.4`
- `lua-curl`

To build a script bundle, [lmerge](https://github.com/ziyao233/lmerge) is
also needed.

### Build Script Bundle

```
	$ cd src
	$ make			# creates rollmeow
	$ chmod +x rollmeow
```

The bundled script `rollmeow` could be run directly.

## Usage

```
	rollmeow [options] [PKGNAME1] [PKGNAME2] ...
```

For options,

- `--conf CONF`: use `CONF` as configuration file
- `--sync`: sync package cache before reporting
- `--diff`: only print outdated packages
- `--json`: JSON format output
- `--info`: show information about a package
- `--showfetched`: show fetched content of the URL, useful for debugging
- `--showmatch`: show regex matches, useful for debugging
- `--manual`: show manually checked packages, which are omitted in
  output for compatibility.
- `--verbose`: be verbose

## Configuration File Format

Configuration file for rollmeow is simply a normal Lua program, which
should return a table with fields listed below:

```
{
	function string evalDownstream(string pkgname)
	function string fetchUpstream(string url)
	string cachePath
	table packages
	number connections
}
```

- `evalDownstream`: Returns downstream version string of package `pkgname`
- `fetchUpstream`: (deprecated) Returns content of `url` as a string
- `connections`: Maximum number of concurrent fetch connections.
- `cachePath`: A path to store upstream version caches.
- `packages`: see next section

## Package Description

There're currently three types of packages and rollmeow fetches their versions
differently,

### Regex-matching packages

```
{
		url:		string
		regex:		string
[OPTIONAL]	postMatch:	string function(string match)
[OPTIONAL]	filter:		boolean function([string] verArray)
[OPTIONAL]	note:		string
}
```

This is the main type and these packages come with both `url` and `regex`
property. rollmeow fetches the URL and synchronize version information based
on the provided regex.

- `url`: URL to fetch
- `regex`: A Lua regex for matching version strings. `-` modifier is not
  available and is recognized as a normal character. A package omitting both
  `regex` and `follow` property will be recognized as manually-checked one.
- `postMatch`: A hook to process matched results. Has no effect on 
- `filter`: Called with each matched version, should return false if
  this version should be ignored. `verArray` is the version string splited
  by dot (`.`)
- `note`: An optional note to the package. Not used internally, but rollmeow
  adds special marks on packages with available notes. Could be listed with
  `--info`.

### Batched packages

```
{
		follow:		string
[OPTIONAL]	url:		string
[OPTIONAL]	note:		string
}
```

These packages come with `follow` property. rollmeow uses version information
of the package specified by `follow` property for them. This type is useful to
track subpackages and grouped packages (for example, KDE).

- `follow`: Specify another package whose version synchronized with this one..

### Manully-checked packages

```
{
		url:		string
[OPTIONAL]	note:		string
}
```

These packages act as placeholders. rollmeow doesn't synchronize or store
version information for them.
