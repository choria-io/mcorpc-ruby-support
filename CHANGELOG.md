|Date      |Issue |Description                                                                                              |
|----------|------|---------------------------------------------------------------------------------------------------------|
|2020/01/12|      |Release 2.23.2                                                                                           |
|2020/01/12|117   |Improve handling of user configuration paths                                                             |
|2020/01/12|      |Release 2.23.1                                                                                           |
|2020/01/10|114   |Support `expr` filters and retire old filter logic                                                       |
|2020/01/05|83    |Restore `mco ping` to being ruby based as a tool for low level testing of the client                     |
|2020/12/29|      |Allow tasks to be run as another user                                                                    |
|2020/12/30|92    |Remove the ability to enroll Puppet CA, use `choria enroll`                                              |
|2020/12/29|      |Release 2.23.0                                                                                           |
|2020/12/27|85    |update `mco choria` to `choria rpc`                                                                      |
|2020/12/26|83    |Update `mco ping` to call `choria ping`                                                                  |
|2020/12/26|83    |Support calling an external binary - like choria - for application plugins                               |
|2020/12/15|63    |Use `choria` in paths for Windows file locations                                                         |
|2020/12/15|75    |Do not raise issues for unsupport config options when parsing server config                              |
|2020/11/25|      |Release 2.22.1                                                                                           |
|2020/10/22|72    |Do not parse registration related settings                                                               |
|2020/07/07|      |Release 2.22.0                                                                                           |
|2020/07/21|69    |Add FreeBSD support                                                                                      |
|2020/07/07|      |Release 2.21.1                                                                                           |
|2020/05/11|65    |Fix facts application when querying non-string facts                                                     |
|2020/01/21|      |Release 2.21.0                                                                                           |
|2019/10/01|50    |Fix executable names when building modules of external agents                                            |
|2020/01/20|60    |Support :hash DDL validations                                                                            |
|2020/01/09|58    |Support :array DDL validations                                                                           |
|2019/11/26|      |Release 2.20.8                                                                                           |
|2019/11/03|52    |Improve handling `--version` in applications                                                             |
|2019/09/19|      |Release 2.20.7                                                                                           |
|2019/09/25|46    |Ensure a valid version of PDK is available when building packages                                        |
|2019/09/25|43    |Ensure external agents are executable                                                                    |
|2019/09/25|40    |Only generate JSON DDls when they do not already exist                                                   |
|2019/09/25|39    |Avoid duplicate resources for packaged plugins wrt to JSON DDL files                                     |
|2019/09/19|      |Release 2.20.6                                                                                           |
|2019/09/18|30    |Move the aiomodule package into this module, retire others                                               |
|2019/09/08|34    |Add support for type in outputs                                                                          |
|2019/08/19|31    |Check client_activated property when loading DDLs                                                        |
|2019/03/04|      |Release 2.20.5                                                                                           |
|2019/02/28|22    |Fix fact summaries for complex data types                                                                |
|2018/11/30|      |Release 2.20.4                                                                                           |
|2018/12/18|19    |Support ~/.choriarc and /etc/choria/client.conf                                                          |
|2018/11/30|      |Release 2.20.3                                                                                           |
|2018/11/30|13    |Restore `rpcutil.ddl`                                                                                    |
|2018/11/22|      |Release 2.20.2                                                                                           |
|2018/11/22|10    |Include the `nats-pure` dependency that choria needs                                                     |
|2018/11/22|      |Release 2.20.1                                                                                           |
|2018/11/22|7     |Do not require the `json` gem which can only be built as a native extension requiring compilers          |
|2018/11/07|      |Release 2.20.0                                                                                           |
|2018/11/03|1     |Create a minimal gem that removes a lot of the unused parts of MCollective                               |
