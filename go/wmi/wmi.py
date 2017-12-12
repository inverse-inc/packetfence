from impacket import version, ntlm
from impacket.dcerpc.v5 import transport, dcomrt
from impacket.dcerpc.v5.dtypes import NULL
from impacket.dcerpc.v5.dcom import wmi
from impacket.dcerpc.v5.dcomrt import DCOMConnection
from impacket.dcerpc.v5.rpcrt import DCERPCException
import json

s = []

def wmitest(domain, username, password, address, namespace, sql):
    import cmd

    class WMIQUERY(cmd.Cmd):
        def __init__(self, iWbemServices):
            cmd.Cmd.__init__(self)
            self.iWbemServices = iWbemServices

        def printReply(self, iEnum):
            global s
            del s[:]
            printHeader = True
            while True:
                try:
                    pEnum = iEnum.Next(0xffffffff,1)[0]
                    record = pEnum.getProperties()
                    if printHeader is True:
                        element = []
                        for col in record:
                            element.append(col)
                        s.append(element)
                    printHeader = False
                    elem = []
                    for key in record:
                        elem.append(record[key]['value'])
                    s.append(elem)
                except Exception, e:
                    #import traceback
                    #print traceback.print_exc()
                    if str(e).find('S_FALSE') < 0:
                        raise
                    else:
                        break
            iEnum.RemRelease()

        def default(self, line):
            line = line.strip('\n')
            if line[-1:] == ';':
                line = line[:-1]
            try:
                iEnumWbemClassObject = self.iWbemServices.ExecQuery(line.strip('\n'))
                self.printReply(iEnumWbemClassObject)
                iEnumWbemClassObject.RemRelease()
            except Exception, e:
                print str(e)

        def emptyline(self):
            pass

        def do_exit(self, line):
            return True


    lmhash = ''
    nthash = ''
    if namespace == '':
        namespace = '//./root/cimv2'
    try:
        dcom = DCOMConnection(address, username, password, domain, lmhash, nthash, oxidResolver = True)
    except DCERPCException:
        res = {
            'Result': "Unable to connect on the remote host",
            }
        final = json.dumps(res)
        return final
    iInterface = dcom.CoCreateInstanceEx(wmi.CLSID_WbemLevel1Login,wmi.IID_IWbemLevel1Login)
    iWbemLevel1Login = wmi.IWbemLevel1Login(iInterface)
    iWbemServices = iWbemLevel1Login.NTLMLogin(namespace , NULL, NULL)
    iWbemLevel1Login.RemRelease()

    shell = WMIQUERY(iWbemServices)

    shell.onecmd(sql)

    iWbemServices.RemRelease()
    dcom.disconnect()
    final = json.dumps(s)
    return final
