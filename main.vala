using GLib;
using Gtk;
using Soup;

public class Main : Object {
    const string UI_FILE = "main.ui";

    // UI elements
    private Window window;
    private MessageDialog error_messagedialog;
    private Image image;
    private FileChooserDialog filechooserdialog;

    private GLib.Settings settings = new GLib.Settings ("org.gnome.desktop.background");
    private string wallpaper_url;
    private Array<string> wallpaper_urls = new Array<string> ();
    private Gdk.PixbufLoader loader;
    private Gdk.Pixbuf pixbuf;
    
    public Main () {
        try {
            var builder = new Builder ();
            builder.add_from_file (UI_FILE);
            builder.connect_signals (this);

            window = builder.get_object ("window") as Window;
            error_messagedialog = builder.get_object ("error_messagedialog") as MessageDialog;
            image = builder.get_object ("image") as Image;
            filechooserdialog = builder.get_object("filechooserdialog") as FileChooserDialog;

            window.show_all ();
        } catch (Error e) {
            // todo: change the error message dialog text and show it
            stderr.printf ("Could not load UI: %s\n", e.message);
        } 
    }

    [CCode (instance_pos = -1)]
    public void on_destroy (Widget window) {
        Gtk.main_quit ();
    }

    [CCode (instance_pos = -1)]
    public void on_refresh_button_clicked (Button source) {
        /*
         * shows the downloaded image
         */
        get_wallpaper_url ();
        
        try {
            var session = new Soup.SessionAsync ();
            var message = new Soup.Message ("GET", wallpaper_url);
            session.send_message (message);

            loader = new Gdk.PixbufLoader ();
            loader.write (message.response_body.data);
            loader.close ();

            pixbuf = loader.get_pixbuf ();

            // scale the image down
            int ratio = 1;
            int width = pixbuf.get_width ();
            int height = pixbuf.get_height ();
            if (width > 480 && height > 300) {
                if (width > height) {
                    ratio = width / 480;
                } else {
                    ratio = height / 300;
                }
            }
            // show image
            image.set_from_pixbuf (
                pixbuf.scale_simple (width / ratio, height / ratio, Gdk.InterpType.BILINEAR)
            );
        } catch (Error e) {
            // todo: set the error message dialog and show it
            // todo: exit this function
        }

    }

    [CCode (instance_pos = -1)]
    public void on_apply_button_clicked (Button source) {
        /*
         * saves the image to a file and updates the desktop background
         */

        // todo: check if image is already loaded
        // todo: remember the user's pref
        int response = filechooserdialog.run ();
        if (response == Gtk.ResponseType.ACCEPT) {
            // todo handle this better, maybe set the currect dir as the default filename
            // todo: change 'jpeg' to the actual file type
            pixbuf.save (filechooserdialog.get_filename (), "jpeg");
            // set the desktop background
            settings.set_string ("picture-uri", filechooserdialog.get_uri ());
            filechooserdialog.hide ();
        } else if (response == Gtk.ResponseType.CANCEL) {
            filechooserdialog.hide ();
        }
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
        // todo: show a loading spinner
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


