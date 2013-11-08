
import Gloebit;

class Index {

  var gbit : Gloebit;


  static function appendElt (id : String, elt : Dynamic) {
    var d = js.Browser.document.getElementById (id);
    if (d == null)
      js.Lib.alert ("Unknown element : " + id);
    d.appendChild (elt);
  }


  static function appendSpan (parent_id : String,
                              new_id : String,
                              content : String) {
    var dom = js.Browser.document;
    var span : js.html.SpanElement = cast dom.createElement("span");
    span.innerText = content;
    span.id = new_id;
    appendElt (parent_id, span);
  }


  static function appendBr (parent_id : String) {
    var dom = js.Browser.document;
    var br : js.html.BRElement = cast dom.createElement("br");
    appendElt (parent_id, br);
  }



  static function update_balance (balance : Float) {
    var d = js.Browser.document.getElementById ("balance-span");
    d.innerText = Std.string (balance);
  }



  static function program (gbit : Gloebit,
                           user_id : String,
                           user_name : String,
                           balance : Float) {
    appendSpan ("top", "uid-span", "uid: " + Std.string (user_id));
    appendBr ("top");

    var name_field : js.html.InputElement =
      cast js.Browser.document.getElementById ('name-field');

    var save_btn : js.html.InputElement =
      cast js.Browser.document.getElementById ('save-name-button');

    var spend_btn : js.html.InputElement =
      cast js.Browser.document.getElementById ('spend-button');

    var visit_btn : js.html.InputElement =
      cast js.Browser.document.getElementById ('visit-button');


    name_field.value = user_name;

    appendSpan ("top", "balance-label-span", "balance: ");
    appendSpan ("top", "balance-span", Std.string (balance));
    appendBr ("top");

    var name_change_handler : js.html.Event -> Void =
      function (e : js.html.Event)
      {
        if (user_name != name_field.value)
          save_btn.disabled = false;
        else
          save_btn.disabled = true;
      }
    untyped
      {
        if (name_field.addEventListener) {
          name_field.addEventListener ("keyup", name_change_handler, false);
        } else {
          name_field.attachEvent ("keyup", name_change_handler, false);
        }
      }


    save_btn.disabled = true;
    var save_name_handler : js.html.Event -> Void =
      function (e : js.html.Event)
      {
        save_btn.disabled = true;
        trace ('new user-name is ' + name_field.value);
        gbit.update_inventory_item ('name', null, name_field.value);
      }
    untyped
      {
        if (save_btn.addEventListener) {
          save_btn.addEventListener ("click", save_name_handler, false);
        } else {
          save_btn.attachEvent ("onclick", save_name_handler, false);
        }
      }


    var spend_handler : js.html.Event -> Void =
      function (e : js.html.Event)
      {
        spend_btn.disabled = true;
        gbit.transact_async
        ("test", 1,
         null, null, null,
         10, name_field.value,
         function (result) {
          trace ("transact result = " + Std.string (result));
          // update_balance (gbit.get_balance ());
          update_balance (result.balance);
          spend_btn.disabled = false;
        });
      }
    untyped
      {
        if ( spend_btn.addEventListener ) {
          spend_btn.addEventListener( "click", spend_handler, false );
        } else {
          spend_btn.attachEvent( "onclick", spend_handler, false );
        }
      }


    var visit_handler : js.html.Event -> Void = gbit.visit_gloebit;
    untyped
      {
        if ( visit_btn.addEventListener ) {
          visit_btn.addEventListener( "click", visit_handler, false );
        } else {
          visit_btn.attachEvent( "onclick", visit_handler, false );
        }
      }


  }


#if false

  static function main () {
    trace("asynchronous version");

    var gbit = new Gloebit ('www.gloebit.com');
    gbit.consumer_key = 'test-consumer';

    gbit.get_user_id_async
      (function (user_id) {
        gbit.get_inventory_item_async
          ('name',
           function (user_name) {
             gbit.get_balance_async
               (function (balance) {
                 program (gbit, user_id, user_name, balance);
               });
           });
      });
  }

#else

  static function main () {
    trace("synchronous version");
    var gbit = new Gloebit ('www.gloebit.com');
    gbit.consumer_key = 'test-consumer';

    var user_id = gbit.get_user_id ();
    if (user_id == null)
      return; /* browser is being redirected */

    var user_name = gbit.get_inventory_item ('name');
    var balance = gbit.get_balance ();
    program (gbit, user_id, user_name, balance);
  }

#end
}
