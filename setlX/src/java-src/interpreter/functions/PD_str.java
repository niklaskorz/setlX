package interpreter.functions;

import interpreter.types.Value;

import java.util.List;

// str(value)              : converts any value into a string

public class PD_str extends PreDefinedFunction {
    public final static PreDefinedFunction DEFINITION = new PD_str();

    private PD_str() {
        super("str");
        addParameter("value");
    }

    public Value execute(List<Value> args, List<Value> writeBackVars) {
        return args.get(0).str();
    }
}

