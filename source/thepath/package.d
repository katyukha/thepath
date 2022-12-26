/** ThePath - easy way to work with paths and files
  *
  * Yet another attempt to implement high-level object-oriented interface
  * to manage path and files in D.
  * Inspired by [Python's pathlib](https://docs.python.org/3/library/pathlib.html)
  * and [D port of pathlib](https://code.dlang.org/packages/pathlib) but
  * implementing it in different way.
  *
  **/
module thepath;

public import thepath.path: Path;
public import thepath.utils: createTempDirectory, createTempPath;
public import thepath.exception: PathException;

/// Example to find configuration of current project
unittest {
    import dshould;

    Path root = createTempPath();
    scope(exit) root.remove();

    // Save current directory
    auto cdir = Path.current;
    scope(exit) cdir.chdir;

    // Create directory structure
    root.join("my-project", "some-dir", "some-sub-dir").mkdir(true);
    root.join("my-project", "utils", "some-utility").mkdir(true);
    root.join("my-project", "tools", "tool42", "s31").mkdir(true);

    // Create some project config file
    root.join("my-project", "my-conf.conf").writeFile("name = My Project");

    // Let's change current working directory to test root
    root.chdir;

    // Let's try to find project config, and expect that no config found,
    // because our current working directory is not inside project
    Path.current.searchFileUp("my-conf.conf").isNull.should.be(true);

    // Let's change directory to our project directory,
    // and try to find our config
    root.chdir("my-project");

    // Ensure that current directory now is my-project
    Path.current.should.equal(root.join("my-project"));

    // Ensure that we can find path to config
    auto config1 = Path.current.searchFileUp("my-conf.conf");
    config1.isNull.should.be(false);
    config1.get.readFileText.should.equal("name = My Project");

    // Let's change directory to 'some-sub-dir' inside our project,
    // and try to find our config again
    root.chdir("my-project", "some-dir", "some-sub-dir");

    // Ensure that current directory now is my-project/some-dir/some-sub-dir
    Path.current.should.equal(
        root.join("my-project", "some-dir", "some-sub-dir"));

    // Ensure that we can find path to config even if we someshere deep inside
    // our project tree
    auto config2 = Path.current.searchFileUp("my-conf.conf");
    config2.isNull.should.be(false);
    config2.get.readFileText.should.equal("name = My Project");
}


/// Example of using nullable paths as function parameters
unittest {
    import dshould;

    import std.typecons: Nullable, nullable;

    /* simple function, that will join 'test.conf' to provided path
     * if provided path is not null, and return null path is provided path
     * is null
     */
    Nullable!Path test_path_fn(in Nullable!Path p) {
        if (p.isNull)
            return Nullable!Path.init;
        return p.get.join("test.conf").nullable;
    }

    // Pass value to nullable param
    auto p1 = test_path_fn(Path("hello").nullable);
    p1.isNull.should.be(false);
    p1.get.segments.should.equal(["hello", "test.conf"]);

    // Pass null to nullable param
    auto p2 = test_path_fn(Nullable!Path.init);
    p1.isNull.should.be(false);
}


/// Example of using paths in structs
unittest {
    import dshould;

    struct PStruct {
        string name;
        Path path;

        bool check() const {
            return path.exists;
        }
    }

    PStruct p;

    p.name = "test";

    // Attempt to run operation on uninitialized path will throw error
    import core.exception: AssertError;
    p.check.should.throwA!AssertError;

    // Let's initialize path and check it again
    p.path = Path("some-unexisting-path-to-magic-file");
    p.check.should.be(false);
}
