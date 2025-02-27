module Spree
  module Admin
    class ShippingMethodsController < ResourceController
      before_filter :load_data, except: [:index]
      before_filter :set_shipping_category, only: [:create, :update]
      before_filter :set_zones, only: [:create, :update]
      before_filter :load_hubs, only: [:new, :edit, :create, :update]

      # Sort shipping methods by distributor name
      def collection
        collection = super
        collection = collection.managed_by(spree_current_user).by_name

        if params.key? :enterprise_id
          distributor = Enterprise.find params[:enterprise_id]
          collection = collection.for_distributor(distributor)
        end

        collection
      end

      def destroy
        # Our reports are not adapted to soft deleted shipping_methods so here we prevent
        #   the deletion (even soft) of shipping_methods that are referenced in orders
        if order = order_referenced_by_shipping_method
          flash[:error] = I18n.t(:shipping_method_destroy_error, number: order.number)
          redirect_to(collection_url) && return
        end

        @object.touch :deleted_at
        flash[:success] = flash_message_for(@object, :successfully_removed)

        respond_with(@object) do |format|
          format.html { redirect_to collection_url }
        end
      end

      private

      def order_referenced_by_shipping_method
        Order.joins(shipments: :shipping_rates)
          .where( spree_shipping_rates: { shipping_method_id: @object } )
          .first
      end

      def load_hubs
        # rubocop:disable Style/TernaryParentheses
        @hubs = Enterprise.managed_by(spree_current_user).is_distributor.sort_by! do |d|
          [(@shipping_method.has_distributor? d) ? 0 : 1, d.name]
        end
        # rubocop:enable Style/TernaryParentheses
      end

      def set_shipping_category
        return true if params["shipping_method"][:shipping_categories] == ""
        @shipping_method.shipping_categories =
          Spree::ShippingCategory.where(id: params["shipping_method"][:shipping_categories])
        @shipping_method.save
        params[:shipping_method].delete(:shipping_categories)
      end

      def set_zones
        return true if params["shipping_method"][:zones] == ""
        @shipping_method.zones = Spree::Zone.where(id: params["shipping_method"][:zones])
        @shipping_method.save
        params[:shipping_method].delete(:zones)
      end

      def location_after_save
        edit_admin_shipping_method_path(@shipping_method)
      end

      def load_data
        @available_zones = Zone.order(:name)
        @calculators = ShippingMethod.calculators.sort_by(&:name)
      end
    end
  end
end
