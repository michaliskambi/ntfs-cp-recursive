# Command-line utility using `ntfs-3g` tools to copy directories from NTFS partition

## Purpose

This is a tool to recursively copy a directory from an NTFS partition. "Recursively" means it is copied with contents (including files and subdirectories, up to a specified depth).

Under the hood, this tool uses `ntfsls` and `ntfscat` utilities from `ntfs-3g`. These underlying `ntfs-3g` utilities work on an NTFS partition without mounting it. This is useful when you cannot mount the partition, e.g. because the hard disk is physically damaged. In such case, the `ntfs-3g` tools may still allow to extract at least *some* files from the partition.

## Usage

Compile using [Free Pascal Compiler](https://www.freepascal.org/), simply execute

```
fpc ntfs-cp-recursive.lpr
```

Run like

```
sudo ntfs-cp-recursive [OPTIONS...] DEVICE SOURCE-PATH
```

Allowed OPTIONS are:

* `--depth DEPTH` : limit recursion depth. Use -1 (default) to not limit depth.

* `--dry-run` : do not copy files or create directories. In effect we will only list what would be done.

* `--exclude MASK` : add given mask to exclude directories and files from copying. Use it multiple times to exclude many things.

```
# Copy stuff from c:/cygwin64/home/michalis on Windows.
sudo ntfs-cp-recursive --dry-run /dev/sda1 cygwin64/home/michalis
sudo ntfs-cp-recursive /dev/sda1 cygwin64/home/michalis
```

The indicated path is copied into the current directory. In the example above, after executing `sudo ntfs-cp-recursive /dev/sda1 cygwin64/home/michalis`, you will see a subdirectory `michalis` in the current dir.

## Notes

* You should run it as `root`, as NTFS tools need direct access to disk devices. That's why I show `sudo` in examples above.

* The process is quite slow (definitely much slower than using a mounted partition). Use `--exclude` to omit subdirectories and files that are not interesting.

* Note that we pass `--force` underneath to ntfs-3g tools, to deal with dirty disks (the purpose of this tool is to be used on badly damaged disks).

* We create output subdirectories if necessary. You can rerun the script multiple times, with ever increasing `--depth`, to get more and more files.

* If you need to recover NTFS stuff, see also other tools from `ntfs-3g`, like `ntfsclone` with `--rescue`.

## License

Copyright Michalis Kamburelis.

License: GNU GPL >= 3.
