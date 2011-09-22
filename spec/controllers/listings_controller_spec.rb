require 'spec_helper'

describe ListingsController do

  describe "GET 'showimage'" do
    it "should be successful" do
      get 'showimage'
      response.should be_success
    end
  end

end
