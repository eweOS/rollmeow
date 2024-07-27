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
- `--showmatch`: show regex matches, useful for debugging
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

## Package Format

```
{
	url:		string
	regex:		string
	postMatch:	string function(string match)
	filter:		boolean function([string] verArray)
}
```

- `url`: URL to fetch
- `regex`: A Lua regex, will be used to match version strings
  `-` modifier is not available and is recognized as a normal character
- `postMatch`: A hook to process matched results.
- `filter`: Called with each matched version, should return false if
  this version should be ignored. `verArray` is the version string splited
  by dot (`.`)

`url` and `regex` are required for all packages.
