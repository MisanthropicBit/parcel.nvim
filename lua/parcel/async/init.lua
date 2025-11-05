local async_proxy = require("parcel.async.proxy")
local lazy_require = require("parcel.utils.lazy_require")

local async_lazy_require = lazy_require.prefixed_lazy_require("parcel.async")

return {
    api = async_proxy.create("api"),
    event = async_lazy_require("event"),
    fn = async_proxy.create("fn"),
    fs = async_lazy_require("fs"),
    opt = async_proxy.create("opt"),
    opt_local = async_proxy.create("opt_local"),
    opt_global = async_proxy.create("opt_global"),
    process = async_lazy_require("process"),
    utils = async_lazy_require("utils"),
}
