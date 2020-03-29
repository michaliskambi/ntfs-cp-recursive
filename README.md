# Command-line utility using `ntfs-3g` tools to copy directories from NTFS partition

## Purpose

This is a tool to recursively copy a directory from an NTFS partition. "Recursively" means it is copied with contents (including files and subdirectories, up to a specified depth).

This tool uses `ntfsls` and `ntfscat` utilities from `ntfs-3g`. The underlying `ntfs-3g` tools allow to work on an NTFS partition without mounting it. They are particularly useful when you cannot mount the partition, because the hard disk is badly damaged. In such case, the `ntfs-3g` tools allow to extract at least *some* files from the partition.

## Usage

Compile using [Free Pascal Compiler](https://www.freepascal.org/), simply execute

```
fpc ntfs-cp-recursive.lpr
```

Run like

```
sudo ntfs-cp-recursive [OPTIONS...] DEVICE SOURCE-PATH
```

where OPTIONS can only be:

* `--depth DEPTH` : limit recursion depth. Use -1 (default) to not limit depth.

* `--dry-run` : do not copy files or create directories. In effect we will only list what would be done.

* `--exclude MASK` : add given mask to exclude directories and files from copying. Use it multiple times to exclude many things.

```
# Copy stuff from c:/cygwin64/home/michalis on Windows.
sudo ntfs-cp-recursive --dry-run /dev/sda1 cygwin64/home/michalis
sudo ntfs-cp-recursive /dev/sda1 cygwin64/home/michalis
```

## Notes

* You should run it as `root`, as NTFS tools need direct access to disk devices. That's why I show `sudo` in examples above.

* The process is quite slow (definitely much slower than using a mounted partition). Use `--exclude` to omit subdirectories and files that are not interesting.

* Note that we pass `--force` underneath to ntfs-3g tools, to deal with dirty disks (the purpose of this tool is to be used on badly damaged disks).

* We create subdirectories if necessary. You can rerun the script multiple times, with ever increasing `--depth`, to get more and more files.

* If you need to recover NTFS stuff, see also other tools from `ntfs-3g`, like `ntfsclone` with `--rescue`.

## License

Copyright Michalis Kamburelis.

License: GNU GPL >= 3.
