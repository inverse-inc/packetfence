package detect

type Parser interface {
    Parse(string) ([]ApiCall, error)
}

type ApiCall interface{
   Call() error 
}

type JsonRpcApiCall struct {
    Method string
    Params interface{} 
}

func (*JsonRpcApiCall) Call() error {
    return nil
}

