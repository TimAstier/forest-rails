module ForestLiana
  class StripePaymentsGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      @reference_model, @reference_field = reference_model(reference)
      Stripe.api_key = secret_key
    end

    def count
      @charges.try(:total_count) || 0
    end

    def perform
      params = { limit: 10 }

      if @params[:page]
        params[:starting_after] = @params[:page][:lastItemId] \
          if @params[:page][:lastItemId]

        params[:ending_before] = @params[:page][:firstItemId] \
          if @params[:page][:firstItemId]
      end

      if reference_model_id
        resource = @reference_model.find(reference_model_id)
        params[:customer] = resource[@reference_field]

        if params[:customer]
          fetch_charges(params)
        else
          @records = []
        end
      else
        fetch_charges(params)
      end
    end

    def fetch_charges(params)
      params['include[]'] = 'total_count'

      @charges = Stripe::Charge.all(params)
      @records = @charges.data.map do |d|
        d.created = Time.at(d.created).to_datetime
        d.amount /= 100

        query = {}
        query[@reference_field] = d.customer
        d.customer = @reference_model.find_by(query)

        d
      end
    end

    def reference_model(reference)
      resource_name, reference_field = reference.split('.')
      reference_model = SchemaUtils.find_model_from_table_name(resource_name)

      [reference_model, reference_field]
    end

    def reference_model_id
      @params["#{@reference_model.table_name.singularize()}Id"]
    end
  end
end