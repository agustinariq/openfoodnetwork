require 'spec_helper'

describe Spree::ProductSet do
  describe '#save' do
    context 'when passing :collection_attributes' do
      let(:product_set) do
        described_class.new(collection_attributes: collection_hash)
      end

      context 'when the product does not exist yet' do
        let!(:stock_location) { create(:stock_location, backorderable_default: false) }
        let(:collection_hash) do
          {
            0 => {
              product_id: 11,
              name: 'a product',
              price: 2.0,
              supplier_id: create(:enterprise).id,
              primary_taxon_id: create(:taxon).id,
              unit_description: 'description',
              variant_unit: 'items',
              variant_unit_name: 'bunches',
              shipping_category_id: create(:shipping_category).id
            }
          }
        end

        it 'creates it with the specified attributes' do
          product_set.save

          expect(Spree::Product.last.attributes)
            .to include('name' => 'a product')
        end
      end

      context 'when the product does exist' do
        context 'when a different varian_unit is passed' do
          let!(:product) do
            create(
              :simple_product,
              variant_unit: 'items',
              variant_unit_scale: nil,
              variant_unit_name: 'bunches',
              unit_value: nil,
              unit_description: 'some description'
            )
          end

          let(:collection_hash) do
            {
              0 => {
                id: product.id,
                variant_unit: 'weight',
                variant_unit_scale: 1
              }
            }
          end

          it 'does not update the product' do
            product_set.save

            expect(product.reload.attributes).to include(
              'variant_unit' => 'items'
            )
          end

          it 'adds an error' do
            product_set.save
            expect(product_set.errors.get(:base))
              .to include("Unit value can't be blank")
          end

          it 'returns false' do
            expect(product_set.save).to eq(false)
          end
        end

        context 'when :master_attributes is passed' do
          let!(:product) { create(:simple_product) }
          let(:collection_hash) { { 0 => { id: product.id } } }
          let(:master_attributes) { { sku: '123' } }

          before do
            collection_hash[0][:master_attributes] = master_attributes
          end

          context 'and the variant does exist' do
            let!(:variant) { create(:variant, product: product) }

            before { master_attributes[:id] = variant.id }

            it 'updates the attributes of the master variant' do
              product_set.save
              expect(variant.reload.sku).to eq('123')
            end
          end

          context 'and the variant does not exist' do
            context 'and attributes provided are valid' do
              let(:master_attributes) do
                attributes_for(:variant).merge(sku: '123')
              end

              it 'creates it with the specified attributes' do
                number_of_variants = Spree::Variant.all.size
                product_set.save
                expect(Spree::Variant.last.sku).to eq('123')
                expect(Spree::Variant.all.size).to eq number_of_variants + 1
              end
            end

            context 'and attributes provided are not valid' do
              let(:master_attributes) do
                # unit_value nil makes the variant invalid
                # on_hand with a value would make on_hand be updated and fail with exception
                attributes_for(:variant).merge(unit_value: nil, on_hand: 1, sku: '321')
              end

              it 'does not create variant and notifies bugsnag still raising the exception' do
                expect(Bugsnag).to receive(:notify)
                number_of_variants = Spree::Variant.all.size
                expect { product_set.save }
                  .to raise_error(StandardError)
                expect(Spree::Variant.all.size).to eq number_of_variants
                expect(Spree::Variant.last.sku).not_to eq('321')
              end
            end
          end
        end
      end
    end
  end
end
