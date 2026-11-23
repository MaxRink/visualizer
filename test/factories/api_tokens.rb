FactoryBot.define do
  factory :api_token do
    user
    name { "Upload key" }
  end
end
