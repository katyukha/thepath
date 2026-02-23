# Changelog

## Release v2.2.0

### New features

- Added `Path.move` method that moves a path to a new destination. Attempts an
  atomic OS rename first; if source and destination are on different filesystems
  (`EXDEV` on Posix, `ERROR_NOT_SAME_DEVICE` on Windows) it falls back to a
  copy-then-delete. The copy is guarded by a `scope(failure)` that removes a
  partial destination on error.

### Bug fixes

- Fixed missing tilde (`~`) expansion in `copyFileTo` (both source and
  destination paths), `setAttributes`, `symlink`, and the `chown` Posix syscall.
- Fixed `chown` with `recursive=true` re-walking already-visited subdirectories,
  causing O(n²) syscall count on deep trees.
- Fixed wrong error message in `chown(username, groupname, ...)`: the group
  lookup failure now reports the group name instead of the user name.
- Fixed `copyTo`: format placeholder `%s` in the `enforce` message now receives
  the source path as its argument.
- Removed spurious `return` on the void `std.file.rename` call inside `rename`.

---

## Release v2.1.0

- Added `Path.home` static func, that allows to get user's home directory on posix systems.
- Auto `expandTilde` on `realPath` to avoid errors on attept to `Path("~").realPath`.

## Release v2.0.0

- **Breaking!** Changed signature for `chown` method. now it receives one more
  argument `recursive` that is placed before `followSymlink`. Thus is may be incompatible with 1.x.x version

---

## Release v1.2.0

- Added new methods to `Path` struct:
    - `driveName` that returns Windows drive name
    - `stripDrive` that returns path without drive part
    - `stripExt` that returns path without extension
- Updated doc on `withExt` method, to clarify differents wtih `std.path.withExtension`.

---

## Release v1.1.0

- Added new method `chown`

---

## Release v1.0.0

- Add tempFile static method that allows to open temporary files.
- Remove deprecated `execute` method.
  Use [TheProcess](https://code.dlang.org/packages/theprocess) instead

---

## Release v0.1.7

- Added new param to `Path.parent` method - `absolute`, that is by default set to `true` (to keep backward compatibility).
  If this param is set to `false`, then path will not be converted to absolute path before computing parent path,
  thus it will be possible to get non-absolute parent path from non-absolute path.
  For example:

  ```d
  Path("parent", "child").parent == Path.current.join("parent");
  Path("parent", "child").parent(false) == Path("parent");
  ```
