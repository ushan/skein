/**
 * Created with IntelliJ IDEA.
 * User: mobitile
 * Date: 5/6/14
 * Time: 10:35 AM
 * To change this template use File | Settings | File Templates.
 */
package skein.rest.client.impl
{
import flash.net.URLRequestHeader;
import flash.utils.ByteArray;

import skein.core.skein_internal;
import skein.rest.client.impl.URLLoadersQueue;
import skein.rest.client.impl.URLLoadersQueue;
import skein.rest.core.HeaderHandler;
import skein.rest.errors.DataProcessingError;
import skein.rest.errors.UnknownServerError;
import skein.logger.Log;
import skein.utils.StringUtil;

use namespace skein_internal;
public class HandlerAbstract
{
    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------

    public function HandlerAbstract(client:DefaultRestClient)
    {
        super();

        this.client = client;

        // TODO: Add handling of Event.CLOSE event
    }

    //--------------------------------------------------------------------------
    //
    //  Variables
    //
    //--------------------------------------------------------------------------

    protected var client:DefaultRestClient;

    protected var responseCode:int;

    protected var attempts:uint;

    protected var responseHeaders:Array;

    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------

    protected function dispose():void
    {
        client.free()
    }

    //--------------------------------------------------------------------------
    //
    //  Handlers
    //
    //--------------------------------------------------------------------------

    //-------------------------------------
    //  Handlers: status
    //-------------------------------------

    protected function status(code:int):void
    {
        responseCode = code;

        if (client.statusCallback != null)
            client.statusCallback(code);
    }

    //-------------------------------------
    //  Handlers: headers
    //-------------------------------------

    protected function headers(headers:Array):void
    {
        responseHeaders = headers;

        for each (var header:URLRequestHeader in responseHeaders)
        {
            switch (header.name.toLowerCase())
            {
                case "content-type" :
                    client.setResponseContentType(header.value);
                    break;
            }

            var callback:Function =
                client.headerCallbacks[header.name] || HeaderHandler.forName(header.name);

            if (callback != null)
            {
                callback.apply(null, [header]);
            }
        }
    }

    //-------------------------------------
    //  Handlers: progress
    //-------------------------------------

    protected function progress(loaded:Number, total:Number):void
    {
        client.handleProgress(false, loaded, total);
    }

    //-------------------------------------
    //  Handlers: result
    //-------------------------------------

    protected function result(data:Object):void
    {
        Log.i("skein-rest", URLLoadersQueue.name(client.loader) + " " + client.request.method.toUpperCase() + " " + client.request.url + " " + responseCode + " <- " + (data is ByteArray ? "%BINARY_DATA%" : data));

        // indicates if result callback was called before an exception occurred
        var isDataSerializedSuccessfully:Boolean = false;

        try
        {
            client.decodeResult(data,
                function(value:Object):void
                {
                    isDataSerializedSuccessfully = true;

                    if (value is Error)
                    {
                        handleError(value);
                    }
                    else
                    {
                        handleResult(data, value);
                    }
                });
        }
        catch (error:Error)
        {
            if (isDataSerializedSuccessfully) {
                Log.e("skein-rest", "Error during handling result: " + error + ". Please fix this issue as it may cause unexpected behaviour.");
            } else {
                trace(error);
                handleError(new DataProcessingError("An incorrect or invalid data was received."));
            }
        }
    }

    protected function handleResult(rawData:Object, decodedValue:Object):void
    {
        if (client.beforeResultInterceptor != null) {
            client.beforeResultInterceptor(rawData);
        }

        client.handleResult(decodedValue, responseCode, responseHeaders, function():void
        {
            if (client.afterResultInterceptor) {
                client.afterResultInterceptor(rawData);
            }

            dispose();
        });
    }

    //-------------------------------------
    //  Handlers: error
    //-------------------------------------

    protected function error(data:Object):void
    {
        Log.e("skein-rest", StringUtil.substitute("{0} {1} {2}{3} <- {4} {5}",
            URLLoadersQueue.name(client.loader),
            client.request.method.toUpperCase(),
            client.request.url,
            client.request.data ? " -> " + client.request.data : "",
            responseCode,
            data is ByteArray ? "%BINARY_DATA%" : data));

        var isErrorSerializedSuccessfully: Boolean = false;
        try {
            client.decodeError(data, function (info: Object): void {
                isErrorSerializedSuccessfully = true;
                handleError(info);
            });
        } catch (error: Error) {
            if (isErrorSerializedSuccessfully) {
                Log.e("skein-rest", "Error during handling error: " + error + ". Please fix this issue as it may cause unexpected behaviour.");
            } else {
                handleError(new UnknownServerError("An error message received from server could not be parsed."));
            }
        }
    }

    protected function handleError(info:Object):void
    {
        if (client.errorInterceptor != null)
        {
            interceptError(info);
        }
        else if (client.errorCallback != null)
        {
            proceedError(info);
        }
        else
        {
            dispose();
        }
    }

    private function interceptError(info:Object):void
    {
        var proceedErrorCallback:Function = function():void
        {
            proceedError(info);
        };

        var retryRequestCallback:Function = function():void
        {
            retryRequest(info);
        };

        if (client.errorInterceptor.length == 2)
            client.errorInterceptor(info, responseCode)(attempts, proceedErrorCallback, retryRequestCallback);
        else
            client.errorInterceptor(info)(attempts, proceedErrorCallback, retryRequestCallback);
    }

    private function retryRequest(info:Object):void
    {
        if (client.retry())
        {
            attempts++;
        }
        else
        {
            proceedError(info);
        }
    }

    private function proceedError(info:Object):void
    {
        client.handleError(info, responseCode);

        dispose();
    }
}
}
