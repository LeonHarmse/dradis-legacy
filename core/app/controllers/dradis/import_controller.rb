module Dradis
  # The ImportController provides access to the different import plugins that 
  # have been deployed in the dradis server.
  #
  # Each import plugin will include itself in the Plugins::Import module and this
  # controller will include it so all the functionality provided by the different
  # plugins is exposed.
  #
  # For more information on import plugins see:
  # http://dradisframework.org/import_plugins.html
  class ImportController < AuthenticatedController
    before_filter :validate_source, :only => [:filters, :search]
    before_filter :validate_filter, :only => :search

    def list
      plugin_list = Dradis::Core::Plugins::with_feature(:import)
      import_list = []
      plugin_list.each do |plugin|
        import_list << {
          display: "#{plugin.plugin_name} (#{plugin.name} #{plugin::VERSION})",
          value: plugin.name
        }
      end
      # maybe we could improve this by only doing the processing in :json format
      # however, it's not a lot of processing and hopefully in the future we'll
      # also support :html format
      respond_to do |format|
        format.html{ redirect_to root_path }
        format.json { render json: import_list }
      end
    end

    # For a given data source, list all the Filters exposed by the corresponding
    # import plugin.
    # Only supports JSON format.
    def filters
      respond_to do |format|
        format.html{ redirect_to root_path }
        format.json{
          list = [
            {
              :display => 'This source does not define any filters',
              :value => 'invalid'
            }
          ]
          filters_module = :Filters
          if (@source.constants.include?(filters_module))
            list.clear
            @source::Filters.constants.each do |filter_name|
              filter = "#{@source.name}::Filters::#{filter_name}".constantize
              list << {
                :display => "#{filter_name}: #{filter::NAME}",
                :value => filter_name
              }
            end
          end

          render :json => list
        }
      end

      # Run a query against the remote data source using a given filter.
      # Only supports JSON format.
      def search
        respond_to do |format|
          format.html{ redirect_to root_path }
          format.json{
            render :json => @filter.run(params)
          }
        end
      end

    end

    protected
    # Ensure that the data source requested is valid.
    def validate_source()
      valid_sources = Dradis::Core::Plugins::with_feature(:import).map(&:to_s)

      if (params.key?(:scope) && valid_sources.include?(params[:scope])) 
        @source = params[:scope].constantize
      else
        redirect_to root_path
      end
    end

    # If the source is valid, ensure that it defines the requested filter.
    def validate_filter()
      filter_name = params[:filter]
      if (params.key?(:filter) && @source::Filters::constants.include?(filter_name.to_sym))
        @filter = "#{@source.name}::Filters::#{filter_name}".constantize
      else
        redirect_to root_path
      end
    end    
  end
end
