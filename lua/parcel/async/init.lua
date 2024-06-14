local async_proxy = require("parcel.async.proxy")

return {
    api = async_proxy.create("api"),
    event = require("parcel.async.event"),
    fn = async_proxy.create("fn"),
    fs = require("parcel.async.fs"),
    opt = async_proxy.create("opt"),
    opt_local = async_proxy.create("opt_local"),
    opt_global = async_proxy.create("opt_global"),
    process = require("parcel.async.process"),
}
