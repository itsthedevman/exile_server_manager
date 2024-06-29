module ESM
  module Event
    class ServerInitialization
      alias_method :original_build_territory_admins, :build_territory_admins

      def build_territory_admins
        original_build_territory_admins + ESM::Test.territory_admin_uids
      end
    end
  end
end
