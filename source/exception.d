module thepath.exception;


/// PathException - will be raise on failure on path (or file) operations
class PathException : Exception {

    /// Main constructor
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}



