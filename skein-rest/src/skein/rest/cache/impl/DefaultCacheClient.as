/**
 * Created by Max Rozdobudko on 10/2/15.
 */
package skein.rest.cache.impl
{
import flash.net.URLRequest;

import skein.core.skein_internal;

import skein.rest.cache.CacheClient;
import skein.rest.cache.CacheStorageRegistry;
import skein.rest.cache.CacheStorage;
import skein.rest.cache.response.Headers;

public class DefaultCacheClient implements CacheClient
{
    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------

    public function DefaultCacheClient()
    {
        super();
    }

    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------

    private var ignoringParams:Array = [];

    skein_internal function setIgnoreParams(value:Array):void
    {
        ignoringParams = value;
    }

    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------

    //-------------------------------------
    //  Methods: Public API
    //-------------------------------------

    public function head(request:URLRequest):Headers
    {
        var storage:CacheStorage = CacheStorageRegistry.storage();

        if (storage != null)
        {
            var url:String = retrieveURL(request);

            var headers:Headers = storage.head(url);

            return headers;
        }

        return null;
    }

    public function live(request:URLRequest):Boolean
    {
        var storage:CacheStorage = CacheStorageRegistry.storage();

        if (storage != null)
        {
            var url:String = retrieveURL(request);

            var headers:Headers = storage.head(url);

            if (headers != null)
            {
                if (headers.cacheControl)
                {
                    if (headers.cacheControl.noCache)
                    {
                        return false;
                    }
                }

                if (headers.expires)
                {
                    var now:Date = new Date();

                    if (headers.expires.date.time > now.time)
                    {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    public function find(request:URLRequest, callback:Function):void
    {
        var storage:CacheStorage = CacheStorageRegistry.storage();

        if (storage != null)
        {
            var url:String = retrieveURL(request);

            storage.find(url, callback);
        }
        else
        {
            callback(null);
        }
    }

    public function keep(request:URLRequest, data:Object, responseHeaders:Array, callback:Function = null):Boolean
    {
        var storage:CacheStorage = CacheStorageRegistry.storage();

        if (storage != null)
        {
            var headers:Headers = Headers.valueOf(responseHeaders);

            if (headers.cacheControl)
            {
                if (headers.cacheControl.noStore)
                {
                    return false;
                }
            }

            var url:String = retrieveURL(request);

            return storage.keep(url, data, headers, callback);
        }

        return false;
    }

    //-------------------------------------
    //  Methods: Public Utils
    //-------------------------------------

    private function retrieveURL(request:URLRequest):String
    {
        var url:String = request.url;

        if (ignoringParams != null && ignoringParams.length > 0 && url.indexOf("?") != -1)
        {
            var splittedURL:Array = url.split("?");

            var oldFields:Array = splittedURL[1].split("&");

            var newFields:Array = [];

            for (var i:int = 0, n:int = oldFields != null ? oldFields.length : 0; i < n; i++)
            {
                if (ignoringParams.indexOf(oldFields[i].split("=")[0]) != -1)
                {
                    continue;
                }

                newFields.push(oldFields[i]);
            }

            if (newFields.length > 0)
            {
                return splittedURL[0] + "?" + newFields.concat("&");
            }
            else
            {
                return splittedURL[0];
            }
        }
        else
        {
            return url;
        }
    }
}
}
