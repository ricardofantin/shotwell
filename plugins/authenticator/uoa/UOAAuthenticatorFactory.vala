namespace Publishing.Authenticator {
    public class Factory : Spit.Publishing.AuthenticatorFactory, Object {
        private static Factory instance = null;
        private Ag.Manager manager = null;
        private Gee.HashSet<string> services;

        public static Factory get_instance() {
            if (Factory.instance == null) {
                Factory.instance = new Factory();
            }

            return Factory.instance;
        }

        private Factory() {
            this.manager = new Ag.Manager.for_service_type("shotwell-sharing");
            this.manager.enabled_event.connect(this.on_account_enabled);
            this.services = new Gee.ArrayList<string>();
        }

        public Gee.List<string> get_available_authenticators() {
            return services;
        }

        public Spit.Publishing.Authenticator? create(string provider,
                                                     Spit.Publishing.PluginHost host) {
            return null;
        }

        private void rebuild_service_list() {
            this.services.clear();

            foreach (var account_service in this.manager.get_enabled_account_services()) {
                services.add(account_service.get_account().get_provider_name());
            }
        }
    }
}
