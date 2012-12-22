package org.randoom.setlx.functions;

import org.randoom.setlx.types.Value;
import org.randoom.setlx.utilities.State;

import java.util.List;

// isError(value)          : test if value-type is error

public class PD_isError extends PreDefinedFunction {
    public final static PreDefinedFunction DEFINITION = new PD_isError();

    private PD_isError() {
        super("isError");
        addParameter("value");
    }

    public Value execute(final State state, List<Value> args, List<Value> writeBackVars) {
        return args.get(0).isError();
    }
}
