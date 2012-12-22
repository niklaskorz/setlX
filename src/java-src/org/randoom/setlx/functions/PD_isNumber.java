package org.randoom.setlx.functions;

import org.randoom.setlx.types.SetlBoolean;
import org.randoom.setlx.types.Value;
import org.randoom.setlx.utilities.State;

import java.util.List;

// isNumber(value)         : test if value-type is a rational or real

public class PD_isNumber extends PreDefinedFunction {
    public final static PreDefinedFunction DEFINITION = new PD_isNumber();

    private PD_isNumber() {
        super("isNumber");
        addParameter("value");
    }

    public Value execute(final State state, List<Value> args, List<Value> writeBackVars) {
        Value arg = args.get(0);
        if (arg.isRational() == SetlBoolean.TRUE || arg.isReal() == SetlBoolean.TRUE) {
            return SetlBoolean.TRUE;
        } else {
            return SetlBoolean.FALSE;
        }
    }
}
