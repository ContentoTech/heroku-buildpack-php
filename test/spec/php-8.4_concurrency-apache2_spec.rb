require_relative "php_concurrency_shared"

describe "A PHP 8.4/Apache application for testing WEB_CONCURRENCY behavior", :requires_php_on_stack => "8.4" do
	include_examples "A PHP application for testing WEB_CONCURRENCY behavior", "8.4", "apache2"
end
