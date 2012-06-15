/* Copyright 2010-2012 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution. 
 */

public class Application {
    private static Application instance = null;
    private Gtk.Application app_object;
    
    public virtual signal void starting() {
    }
    
    public virtual signal void exiting(bool panicked) {
    }
    
    private bool running = false;
    private bool exiting_fired = false;
    
    private Application() {
        app_object = new Gtk.Application("org.yorba.shotwell",  GLib.ApplicationFlags.FLAGS_NONE);
    }
    
    public static void init() {
        get_instance();
    }
    
    public static void terminate() {
        get_instance().exit();
    }
    
    public static Application get_instance() {
        if (instance == null)
            instance = new Application();
        
        return instance;
    }
    
    public void start() {
        if (running)
            return;
            
        running = true;
        
        starting();
        app_object.add_window(AppWindow.get_instance());
        
        app_object.run();
        
        running = false;
    }
    
    public void exit() {
        // only fire this once, but thanks to terminate(), it will be fired at least once (even
        // if start() is not called and "starting" is not fired)
        if (exiting_fired || !running)
            return;
        
        exiting_fired = true;
        
        exiting(false);
        if(Gtk.main_level() > 0) 
            Gtk.main_quit();
    
        app_object.quit();
    }
    
    // This will fire the exiting signal with panicked set to true, but only if exit() hasn't
    // already been called.  This call will immediately halt the application.
    public void panic() {
        if (!exiting_fired) {
            exiting_fired = true;
            exiting(true);
        }
        
        Posix.exit(1);
    }
}

