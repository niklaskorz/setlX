package interpreter.expressions;

import interpreter.exceptions.AbortException;
import interpreter.exceptions.SetlException;
import interpreter.types.Value;
import interpreter.utilities.Environment;

public abstract class Expr {
    public Value eval() throws SetlException {
        try {
            return this.evaluate();
        } catch (AbortException ae) {
            throw ae;
        } catch (SetlException se) {
            se.addToTrace("Error in '" + this + "':");
            throw se;
        }
    }

    public abstract Value evaluate() throws SetlException;

    public abstract String toString(int tabs);

    public final String toString() {
        return toString(0);
    }
}

