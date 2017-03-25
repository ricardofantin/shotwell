/* Copyright 2009-2011 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

namespace Publishing.Accounts {

public class SharingAccount {
    private Ag.AccountService account_service = null;

    public SharingAccount(Ag.AccountService account_service) {
        this.account_service = account_service;
    }

    public Signon.AuthSession create_auth_session() throws GLib.Error {
        var auth_data = account_service.get_auth_data();
        debug("Signon-id: %u", auth_data.get_credentials_id());

        return new Signon.AuthSession(auth_data.get_credentials_id(),
                                      auth_data.get_method());
    }

    public Variant get_session_parameters(Variant? extra, out string mechanism) {
        var auth_data = account_service.get_auth_data();
        mechanism = auth_data.get_mechanism();
        Variant data = auth_data.get_login_parameters(extra);
        return data;
    }
}

public class SharingAccounts {
    private static Ag.Manager manager = null;
    private string provider_name;
    private Ag.AccountService[] all_accounts;

    public SharingAccounts(string provider_name) {
        if (manager == null) {
            manager = new Ag.Manager.for_service_type("shotwell-sharing");
        }
        manager.enabled_event.connect(on_account_enabled);

        this.provider_name = provider_name;
        all_accounts = get_accounts();
    }

    private void on_account_enabled(uint account_id) {
        /* To keep the implementation simple, just rebuild the account
         * list from scratch */
        all_accounts = get_accounts();
    }

    private Ag.AccountService[] get_accounts() {
        GLib.List<Ag.AccountService> accounts =
            manager.get_enabled_account_services();

        Ag.AccountService[] list = {};

        foreach (Ag.AccountService account_service in accounts) {
            Ag.Account account = account_service.get_account();
            if (account.get_provider_name() == provider_name) {
                list += account_service;
            }
        }
        return list;
    }

    public bool has_enabled_accounts() {
        return all_accounts.length > 0;
    }

    public string[] list_account_names() {
        string[] names = {};
        foreach (Ag.AccountService account_service in all_accounts) {
            names += account_service.get_account().get_display_name();
        }
        return names;
    }

    public SharingAccount? find_account(string? account_name) {
        foreach (Ag.AccountService account_service in all_accounts)
            if (account_service.get_account().get_display_name() == account_name) {
                return new SharingAccount(account_service);
            }

        return null;
    }
}

public class UOAPublisherAuthenticator : Object {
    private weak Spit.Publishing.PluginHost host = null;
    private Signon.AuthSession auth_session = null;
    private SharingAccount account = null;
    private bool firstLoginAttempt = true;
    private bool invalidate_session = false;
    private string welcome_message = null;

    public UOAPublisherAuthenticator(SharingAccount account,
                                     Spit.Publishing.PluginHost host,
                                     string welcome_message)
    {
        this.host = host;
        this.account = account;
        this.welcome_message = welcome_message;
    }

    public signal void authenticated(owned Variant session_data);

    public void authenticate() {
        debug("ACTION: authentication requested.");

        do_authentication();
    }

    public Variant? get_authentication_data() {
        if (account == null) return null;
        string mechanism = null;
        return account.get_session_parameters(null, out mechanism);
    }

    public void invalidate_persistent_session() {
        this.invalidate_session = true;
    }

    private void do_authentication() {
        debug("ACTION: authenticating.");

        if (account != null) {
            try {
                auth_session = account.create_auth_session();
            } catch (GLib.Error e) {
                warning("EVENT: couldn't create session for account: %s",
                        e.message);
            }
        }

        VariantBuilder builder = new VariantBuilder(new VariantType("a{sv}"));

        if (firstLoginAttempt) {
            firstLoginAttempt = false;
            builder.add ("{sv}", "UiPolicy",
                         new Variant.int32((int)Signon.SessionDataUiPolicy.NO_USER_INTERACTION));
        } else {
            var windowId = host.get_dialog_xid();
            if (windowId != 0) {
                builder.add ("{sv}", "WindowId",
                             new Variant.uint32((uint)windowId));
            }
        }

        if (invalidate_session) {
            invalidate_session = false;
            builder.add("{sv}", "ForceTokenRefresh", new Variant.boolean(true));
        }

        string mechanism = null;
        Variant data = account.get_session_parameters(builder.end(), out mechanism);
        if (data == null) {
            warning ("No account authentication data");
            host.post_error(new Spit.Publishing.PublishingError.SERVICE_ERROR(
                "Error while accessing the account"));
            return;
        }

        debug("Got account data");

        host.set_service_locked(true);
        auth_session.process_async.begin(data, mechanism, null,
                                         (obj, res) => {
            host.set_service_locked(false);
            try {
                Variant reply = auth_session.process_async.end(res);
                authenticated(reply);
            } catch (GLib.Error error) {
                debug("got error: %s", error.message);
                if (error is Signon.Error.USER_INTERACTION) {
                    debug("User interaction!");
                    do_show_service_welcome_pane();
                } else {
                    host.post_error(new Spit.Publishing.PublishingError.SERVICE_ERROR("Authentication failed"));
                }
            }
        });
    }

    private void do_show_service_welcome_pane() {
        debug("ACTION: showing service welcome pane.");

        host.install_welcome_pane(welcome_message, on_service_welcome_login);
    }

    private void on_service_welcome_login() {
        debug("EVENT: user clicked 'Login' in welcome pane.");

        do_authentication();
    }
}

}

