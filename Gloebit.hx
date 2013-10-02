
import haxe.ds.StringMap;



class Gloebit {

  public var api_hostname : String;

  /* these need to be set on the consumer's server.  see main, below. */
  public var consumer_key : String;
  public var consumer_secret : String;
  public var consumer_user_name : String;
  public var consumer_redirect_uri : String;

  public var request_token : String;
  public var access_token : String;

  /* cache user id */
  public var user_id : String;

  static public var scope = 'user balance inventory transact';

  public function new (set_api_hostname)
  {
    api_hostname = set_api_hostname;
  }



  /*******************/
  /*** server side ***/
  /*******************/

#if neko


  /* main is called by the api consumer's webserver.  The client code
     below expects to find this program at /Gloebit.n on the same
     webserver that serves the client javascript. */

  static function main ()
  {
    var ctx = new haxe.remoting.Context ();
    var gbit = new Gloebit ('api0.gloebit.com');
    gbit.consumer_key = 'test-consumer';
    gbit.consumer_secret = 's3cr3t';
    gbit.consumer_user_name = 'test-consumer@gloebit.com';
    // gbit.consumer_redirect_uri = 'http://your.web.server/';
    gbit.consumer_redirect_uri = 'http://localhost/';

    ctx.addObject ("Gloebit",
                   {exchange_token: gbit.server_exchange_token,
                    get_user_information: gbit.server_get_user_information,
                    get_inventory_item: gbit.server_get_inventory_item,
                    new_inventory_item: gbit.server_new_inventory_item,
                    update_inventory_item: gbit.server_update_inventory_item,
                    transact: gbit.server_transact,
                    balance: gbit.server_get_balance
                   });

    if (haxe.remoting.HttpConnection.handleRequest (ctx))
      return;

    // handle normal request
    neko.Lib.print ("This is a remoting server !");
  }


  function s4 () {
    var n = Math.floor (Math.random () * 0x10000);
    var result = StringTools.hex (n, 4);
    return result.toLowerCase ();
  }


  public function uuid () {
    return (s4()+s4()+"-"+s4()+"-"+s4()+"-"+s4()+"-"+s4()+s4()+s4());
  }


  public function epoch_time () {
    return Math.round (Date.now ().getTime () / 1000.0);  // XXX utc?
  }



  function server_exchange_token (request_token)
  {
    var access_token_url = new GloebitURL ('');
    access_token_url.protocol = 'https';
    access_token_url.host = api_hostname;
    access_token_url.path = '/oauth2/access-token';
    access_token_url.set_query_args
      (['client_id'=>consumer_key,
        'client_secret'=>consumer_secret,
        'code'=>request_token,
        'scope'=>Gloebit.scope,
        'grant_type'=>'authorization_code',
        'redirect_uri'=>consumer_redirect_uri,
        'state'=>'1']);
    var result = haxe.Http.requestUrl (access_token_url.unparse ());
    return result;
  }


  function do_gloebit_request (path : String, post_data : String) {
    var url = new GloebitURL ('');
    url.protocol = 'https';
    url.host = api_hostname;
    url.path = path;
    var r = new haxe.Http (url.unparse ());
    r.onError = function (err) {trace (err);};
    var response_data = null;
    r.onData = function(data) { response_data = data; }
    r.setHeader("Authorization", "Bearer " + access_token);

    if (post_data != null) {
      r.setPostData (post_data);
      r.request(true);
    }
    else
      r.request(false);
    return response_data;
  }


  function server_get_user_information (access_token)
  {
    this.access_token = access_token;
    return do_gloebit_request ('/user', null);
  }


  function server_get_inventory_item (access_token, item_id)
  {
    this.access_token = access_token;
    return do_gloebit_request ('/get-inventory-item/' + item_id, null);
  }


  function server_new_inventory_item (access_token,
                                      params : String,
                                      type_id : String,
                                      folder_id : String)
  {
    this.access_token = access_token;

    var post_dict = {params: params,
                     type_id: type_id,
                     folder_id: folder_id};
    var post_data = haxe.Json.stringify (post_dict);
    return do_gloebit_request ('/new-inventory-item', post_data);
  }


  function server_update_inventory_item (access_token,
                                         item_id : String,
                                         folder_id : String,
                                         item : String)
  {
    this.access_token = access_token;

    var post_dict = {id : item_id,
                     params: item,
                     folder_id: folder_id};
    var post_data = haxe.Json.stringify (post_dict);
    return do_gloebit_request ('/update-inventory-item', post_data);
  }


  function server_transact (access_token : String,
                            asset_amount : Array<Dynamic>,
                            asset_urls : Array<String>,
                            gloebit_balance_change : Int,
                            merchant_side_user_id : String)
  {
    var asset_code : String = asset_amount[ 0 ];
    var asset_quantity : Float = asset_amount[ 1 ];

    var asset_enact_hold_url : String = asset_urls[ 0 ];
    var asset_consume_hold_url : String = asset_urls[ 1 ];
    var asset_cancel_hold_url : String = asset_urls[ 2 ];

    this.access_token = access_token;

    var version : Int = 1;
    var id : String = uuid ();
    var request_created : Int = epoch_time ();

    var transaction =
      {"consumer-key" : consumer_key,
       "version" : 1,
       "id" : id,
       "request-created" : request_created,
       "asset-code" : asset_code,
       "asset-quantity" : asset_quantity,
       "asset-enact-hold-url" : asset_enact_hold_url,
       "asset-consume-hold-url" : asset_consume_hold_url,
       "asset-cancel-hold-url" : asset_cancel_hold_url,
       "gloebit-balance-change" : gloebit_balance_change,
       "gloebit-recipient-user-name" : consumer_user_name,
       "consumer-key" : consumer_key,
       "merchant-user-id" : merchant_side_user_id};

    var post_data = haxe.Json.stringify (transaction);
    return do_gloebit_request ('/transact', post_data);
  }


  function server_get_balance (access_token)
  {
    this.access_token = access_token;
    return do_gloebit_request ('/balance', null);
  }


#end


  /*******************/
  /*** client side ***/
  /*******************/


#if js


  function get_request_token () {
    var url = new GloebitURL (js.Browser.window.location.href);
    var qargs = url.get_query_args ();
    if (! qargs.exists ('code')) {
      // we have no request-token.  redirect to oauth2 server
      var auth_url = new GloebitURL ('');
      auth_url.protocol = 'https';
      auth_url.host = api_hostname;
      auth_url.path = '/oauth2/authorize';
      auth_url.set_query_args (['scope'=>Gloebit.scope,
                                'redirect_uri'=>url.unparse (),
                                'response_type'=>'code',
                                'client_id'=>consumer_key,
                                'access_type'=>'offline']);

      trace (auth_url.unparse ());
      js.Browser.window.location.href = auth_url.unparse ();
      return null;
    }
    else {
      request_token = qargs.get ('code');
      return request_token;
    }
  }


  function get_request_token_async (thunk) {
    var url = new GloebitURL (js.Browser.window.location.href);
    var qargs = url.get_query_args ();
    if (! qargs.exists ('code')) {
      // we have no request-token.  redirect browser to oauth2 server
      var auth_url = new GloebitURL ('');
      auth_url.protocol = 'https';
      auth_url.host = api_hostname;
      auth_url.path = '/oauth2/authorize';
      auth_url.set_query_args (['scope'=>Gloebit.scope,
                                'redirect_uri'=>url.unparse (),
                                'response_type'=>'code',
                                'client_id'=>consumer_key,
                                'access_type'=>'offline']);

      trace (auth_url.unparse ());
      js.Browser.window.location.href = auth_url.unparse ();
    }
    else {
      request_token = qargs.get ('code');
      thunk ();
    }
  }



  function get_access_token () {
    if (request_token == null) {
      trace ('request token is null');
      if (get_request_token () == null)
        return null;
    }

    var server_url = "/Gloebit.n";
    var cnx = haxe.remoting.HttpConnection.urlConnect (server_url);
    var access_token_json = cnx.Gloebit.exchange_token.call ([request_token]);
    trace ("received access-token: " + access_token_json);

    var access_token_data : GloebitAccessTokenData =
      haxe.Json.parse (access_token_json);

    access_token = access_token_data.access_token;
    return access_token;
  }



  function get_access_token_async (thunk) {
    if (request_token == null) {
      get_request_token_async (function () {
          get_access_token_async (thunk);
        });
      return;
    }

    var server_url = "/Gloebit.n";
    var cnx = haxe.remoting.HttpAsyncConnection.urlConnect (server_url);
    cnx.setErrorHandler (function(err) {
        trace ("Error : " + Std.string (err));
      });
    cnx.Gloebit.exchange_token.call
      ([request_token],
       function (access_token_json) {
         trace ("received access-token: " + access_token_json);

         var access_token_data : GloebitAccessTokenData =
           haxe.Json.parse (access_token_json);

         access_token = access_token_data.access_token;
         thunk ();
       });
  }


  function do_backend_call (function_name : String, args : Array<Dynamic>) {
    if (access_token == null) {
      trace ('token is null');
      if (get_access_token () == null)
        return null;
    }

    var server_url = "/Gloebit.n";
    var cnx = haxe.remoting.HttpConnection.urlConnect (server_url);
    var aargs : Array<Dynamic> = [access_token];
    return cnx.Gloebit.resolve (function_name).call (aargs.concat (args));
  }


  function do_async_backend_call (function_name : String,
                                  args : Array<Dynamic>,
                                  json_consumer) {
    if (access_token == null) {
      get_access_token_async
        (function () {
          do_async_backend_call (function_name, args, json_consumer);
        });
      return;
    }

    var server_url = "/Gloebit.n";
    var cnx = haxe.remoting.HttpAsyncConnection.urlConnect (server_url);
    cnx.setErrorHandler (function (err) {
        trace ("Error : " + Std.string (err));
      });
    var aargs : Array<Dynamic> = [access_token];
    cnx.Gloebit.resolve (function_name).call (aargs.concat (args),
                                              json_consumer);
  }


  public function get_user_id_async (callback)
  {
    if (user_id != null) {
      callback (user_id);
      return;
    }

    do_async_backend_call
      ("get_user_information", [],
       function (user_information_json) {
         trace ("received user information: " + user_information_json);

         var user_data : GloebitUserData =
           haxe.Json.parse (user_information_json);

         user_id = user_data.id;

         callback (user_id);
       });
  }


  public function get_user_id ()
  {
    if (user_id != null)
      return user_id;
    var result_json = do_backend_call ("get_user_information", []);
    var result : GloebitUserData = haxe.Json.parse (result_json);
    return result.id;
  }


  public function get_inventory_item_async (item_id, callback)
  {
    do_async_backend_call
      ("get_inventory_item", [item_id],
       function (result_json) {
         var result = haxe.Json.parse (result_json);
         callback (result.item);
       });
  }


  public function get_inventory_item (item_id)
  {
    var result_json = do_backend_call ("get_inventory_item", [item_id]);
    var result : GloebitInventoryIem = haxe.Json.parse (result_json);
    return result.item;
  }


  public function new_inventory_item_async (item, type_id, folder_id,
                                            callback)
  {
    do_async_backend_call ("new_inventory_item",
                           [item, type_id, folder_id],
                           callback);
  }


  public function new_inventory_item (item, type_id, folder_id)
  {
    return do_backend_call ("new_inventory_item",
                            [item, type_id, folder_id]);
  }



  public function update_inventory_item_async (item_id, folder_id, item,
                                               callback)
  {
    do_async_backend_call ("update_inventory_item",
                           [item_id, folder_id, item], callback);
  }


  public function update_inventory_item (item_id, folder_id, item)
  {
    return do_backend_call ("update_inventory_item",
                            [item_id, folder_id, item]);
  }


  public function transact_async (asset_code,
                                  asset_quantity,
                                  asset_enact_hold_url,
                                  asset_consume_hold_url,
                                  asset_cancel_hold_url,
                                  gloebit_balance_change,
                                  merchant_side_user_id,
                                  callback)
  {
    return do_async_backend_call
      ("transact",
       [[asset_code,
         asset_quantity],
        [asset_enact_hold_url,
         asset_consume_hold_url,
         asset_cancel_hold_url],
        gloebit_balance_change,
        merchant_side_user_id],
       function (result_json) {
         var result : GloebitTransResult = haxe.Json.parse (result_json);
         callback (result);
       });
  }


  public function transact (asset_code,
                            asset_quantity,
                            asset_enact_hold_url,
                            asset_consume_hold_url,
                            asset_cancel_hold_url,
                            gloebit_balance_change,
                            merchant_side_user_id
                            )
  {
    var result_json = do_backend_call ("transact",
                                       [[asset_code,
                                         asset_quantity],
                                        [asset_enact_hold_url,
                                         asset_consume_hold_url,
                                         asset_cancel_hold_url],
                                        gloebit_balance_change,
                                        merchant_side_user_id]);

    var result : GloebitTransResult = haxe.Json.parse (result_json);
    return result;
  }


  public function get_balance_async (callback)
  {
    do_async_backend_call
      ("balance", [],
       function (result_json) {
         var result : GloebitBalance = haxe.Json.parse (result_json);
         if (result.success)
           callback (result.balance);
         else
           callback (null);
       });
  }


  public function get_balance ()
  {
    var result_json = do_backend_call ("balance", []);
    var result : GloebitBalance = haxe.Json.parse (result_json);
    if (result.success)
      return result.balance;
    else
      return null;
  }




  public function visit_gloebit (e : js.html.Event) {
      var auth_url = new GloebitURL ('');
      auth_url.protocol = 'https';
      auth_url.host = api_hostname;
      auth_url.path = '/';
      auth_url.set_query_args (['return-to'=>js.Browser.window.location.href,
                                'r'=>consumer_key]);
      trace (auth_url.unparse ());
      js.Browser.window.location.href = auth_url.unparse ();
  }


#end
}



class GloebitURL
{
  // mostly from http://haxe.org/doc/snip/uri_parser
  // Publics
  public var url : String;
  public var source : String;
  public var protocol : String;
  public var authority : String;
  public var userInfo : String;
  public var user : String;
  public var password : String;
  public var host : String;
  public var port : String;
  public var relative : String;
  public var path : String;
  public var directory : String;
  public var file : String;
  public var query : String;
  public var anchor : String;

  // Privates
  static private var _parts : Array<String> = ["source",
                                               "protocol",
                                               "authority",
                                               "userInfo",
                                               "user",
                                               "password",
                                               "host",
                                               "port",
                                               "relative",
                                               "path",
                                               "directory",
                                               "file",
                                               "query",
                                               "anchor"];

  public function new(url:String)
  {
    // Save for 'ron
    this.url = url;

    // The almighty regexp (courtesy of
    // http://blog.stevenlevithan.com/archives/parseuri)
    var r : EReg = ~/^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/;

    // Match the regexp to the url
    r.match(url);

    // Use reflection to set each part
    for (i in 0..._parts.length)
      {
        Reflect.setField(this, _parts[i],  r.matched(i));
      }
  }

  public function toString() : String
    {
      var s : String = "For Url -> " + url + "\n";
      for (i in 0..._parts.length)
        {
          s += _parts[i] + ": " +
            Reflect.field(this, _parts[i]) + (i==_parts.length-1?"":"\n");
        }
      return s;
    }

  public function get_query_args() : StringMap<String>
    {
      var result = new StringMap<String> ();
      if (query != null) {
        for (nv in query.split ('&')) {
          var parts : Array<String> = nv.split ('=');
          result.set (StringTools.urlDecode (parts[ 0 ]),
                      StringTools.urlDecode (parts[ 1 ]));
        }
      }
      return result;
    }

  public function set_query_args (pairs : StringMap<String>) : Void
    {
      var parts : Array<String> = [];
      for (key in pairs.keys ()) {
        parts.push (StringTools.urlEncode (key) + '=' +
                    StringTools.urlEncode (pairs.get (key)));
      }
      query = parts.join ('&');
    }

  public static function parse(url:String) : GloebitURL
  {
    return new GloebitURL (url);
  }


  public function unparse () : String
    {
      var up_url : String = '';

      if (protocol != null && host != null)
        up_url = protocol + '://' + host;

      if (path == null)
        up_url += '/';
      else
        up_url += path;

      if (query != null) {
        up_url += '?' + query;
      }

      return up_url;
    }
}



/* types used to unparse json from api responses */


typedef GloebitAccessTokenData = {
 access_token:String,
 scope:String,
 refresh_token:String
}


typedef GloebitUserData = {
 id:String
}


typedef GloebitInventoryIem = {
 reason:String,
 success:String,
 item:String
}


typedef GloebitBalance = {
 reason:String,
 success:Bool,
 balance:Float
}


typedef GloebitTransResult = {
 reason:String,
 success:Bool,
 status:String,
 id:String,
 balance:Float
}
