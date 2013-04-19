using GLib;
using Gtk;
using Soup;

public class Main : Object {
    const string UI_FILE = "main.ui";

    private Window window;
    private MessageDialog error_messagedialog;
    private Image image;
    private string wallpaper_url;
    private uint8[] wallpaper_data;
    private Array<string> wallpaper_urls = new Array<string> ();
    private Gdk.PixbufLoader loader;
    private GLib.Settings settings = new GLib.Settings ("org.gnome.desktop.background");
    
    public Main () {
        try {
            var builder = new Builder ();
            builder.add_from_file (UI_FILE);
            builder.connect_signals (this);

            window = builder.get_object ("window") as Window;
            error_messagedialog = builder.get_object ("error_messagedialog") as MessageDialog;
            image = builder.get_object ("image") as Image;

            window.show_all ();
        } catch (Error e) {
            stderr.printf ("Could not load UI: %s\n", e.message);
        } 
    }

    [CCode (instance_pos = -1)]
    public void on_destroy (Widget window) {
        Gtk.main_quit ();
    }

    [CCode (instance_pos = -1)]
    public void on_refresh_button_clicked (Button source) {
        get_wallpaper_url ();
        var session = new Soup.SessionAsync ();
        var message = new Soup.Message ("GET", wallpaper_url);
        session.send_message (message);

        loader = new Gdk.PixbufLoader ();
        loader.size_prepared.connect ((width, height) => {
            int ratio;
            if (width > height) {
                ratio = width / 480;
            } else {
                ratio = height / 300;
            }
            loader.set_size (width / ratio, height / ratio);
        });
        wallpaper_data = message.response_body.data;
        loader.write (wallpaper_data);
        loader.close ();
        image.set_from_pixbuf (loader.get_pixbuf ());
    }

    [CCode (instance_pos = -1)]
    public void on_apply_button_clicked (Button source) {
        // save the image to a file
        // todo: get the actual file type
        // todo: ask the user where to save the file
        // todo: remember the user's pref
        string type = wallpaper_url.split (".")[1];
        string file_path = "/home/archmage/wallpaper.jpg";
        var pixbuf = loader.get_pixbuf ();
        pixbuf.save (file_path, "jpeg");

        // set the desktop background
        settings.set_string ("picture-uri", "file://" + file_path);
    }

    [CCode (instance_pos = -1)]
    public void on_error_messagedialog_response (MessageDialog source, int response_id) {
        switch (response_id) {
            case ResponseType.CLOSE:
                source.hide ();
                break;
        }
    }

    private void get_random_wallpapers () {
        //gets and saves wallpaper urls in wallpaper_urls
        string url = "http://wallbase.cc/random";
        try {
            var session = new Soup.SessionAsync ();
            var message = new Soup.Message ("GET", url);
            session.send_message (message);

            Regex regex = new Regex ("(http://wallbase.cc/wallpaper/[0-9]+)");
            MatchInfo match_info;

            if (regex.match ((string) message.response_body.data, 0, out match_info)) {
                while (match_info.matches ()) {
                    wallpaper_urls.append_val (match_info.fetch(0));
                    match_info.next ();
                }
            } else {
                // todo: show an info message saying that there are no wallpapers
            }
        } catch (Error e) {
            // error dialog
            error_messagedialog.show ();
        }
    }

    private void get_wallpaper_url () {
        /*
         * returns the next wallpapers url
         */
        if (wallpaper_urls.length < 1) {
            get_random_wallpapers ();
        }
        string url = wallpaper_urls.index (0);
        wallpaper_urls.remove_index (0);

        wallpaper_url = "";
        try {
            var session = new Soup.SessionAsync ();
            var message = new Soup.Message ("GET", url);
            session.send_message (message);

            Regex regex = new Regex ("""B\('.+'\)""");
            MatchInfo match_info;

            if (regex.match ((string) message.response_body.data, 0, out match_info)) {
                wallpaper_url = decode_wallpaper_url (match_info.fetch(0)[3:-10]);
            } else {
                // todo: show an info message saying that there are no wallpapers
            }
        } catch (Error e) {
            // error dialog
            error_messagedialog.show ();
        }
    }

    string decode_wallpaper_url (string a) {
        /*
         *  returns a url from decoded string 'a'
         */
        int c, d, e, f, g, h, i, j, k = 0;
        string b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
        string[] n = {};

        if (a.length == 0) {
            return a;
        }
        while (k < a.length) {
            f = b.index_of (a.get_char (k++).to_string ());
            g = b.index_of(a.get_char (k++).to_string ());
            h = b.index_of(a.get_char (k++).to_string ());
            i = b.index_of(a.get_char (k++).to_string ());
            j = f << 18 | g << 12 | h << 6 | i;
            c = j >> 16 & 255;
            d = j >> 8 & 255;
            e = j & 255;
            if (h == 64) {
                n += ((unichar) c).to_string ();
            } else if (i == 64) {
                n += ((unichar) c).to_string ();
                n += ((unichar) d).to_string ();
            } else {
                n += ((unichar) c).to_string ();
                n += ((unichar) d).to_string ();
                n += ((unichar) e).to_string ();
            }
        }
        return string.joinv ("", n);
    }

    static int main (string[] args) {
        Gtk.init (ref args);
        var app = new Main ();

        Gtk.main ();
        
        return 0;
    }
}


