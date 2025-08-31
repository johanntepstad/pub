# eGPT

Welcome to eGPT, a pioneering shell tool powered by OpenAI's GPT-4 and GPT-4V and enhanced with Ruby, LangChain and Weaviate. This tool revolutionizes the command-line by introducing an AI-driven development and information retrieval assistant, capable of understanding and executing commands in natural language.

## Key Features

- **Broad Language Support**: Works across different programming languages and environments.
- **Natural Language Command Processing**: Interact with your development environment using natural language.
- **Domain-Specific Simulation**: Offers specialized assistance for fields like law, architecture, and more.
- **AI-Powered Debugging and Suggestions**: Get intelligent coding assistance, debugging, and optimization recommendations.
- **Dynamic Information Retrieval**: Performs real-time web searches to integrate extensive knowledge directly into your workflow.
- **Security and Privacy**: Adopts rigorous measures to protect sensitive information, focusing on the privacy of court documents.

## Getting Started

### Prerequisites

- Ruby 2.7+
- OpenBSD 7.3 or a compatible system
- API keys for OpenAI, Replicate, and Weaviate

### Installation

Install the necessary dependencies with:

    gem install --user-install specific_install
    gem git_install --user-install https://github.com/andreibondarev/langchainrb.git
    gem git_install --user-install https://github.com/alexrudall/ruby-openai.git
    gem git_install --user-install https://github.com/dreamingtulpa/replicate-ruby.git
    gem git_install --user-install https://github.com/ruby/logger.git
    gem git_install --user-install https://github.com/jnunemaker/httparty.git
    gem git_install --user-install https://github.com/faker-ruby/faker.git
    gem git_install --user-install https://github.com/rubycdp/ferrum.git
    gem git_install --user-install https://github.com/jnunemaker/httparty.git
    gem git_install --user-install https://github.com/ukutaht/safe_ruby.git

Configure your API keys:

    echo "OPENAI_API_KEY=your_api_key" >> ~/.profile
    echo "WEAVIATE_API_KEY=your_api_key" >> ~/.profile
    . /home/dev/.profile

## Usage

eGPT is designed to be intuitive and flexible, adapting to your specific needs through a natural language interface. Here's how you can interact with eGPT for a variety of tasks:

    $ ruby bin/cli
    Welcome to Enhanced GPT. Type `exit` to quit.

**Web development assistance:**

    You> Please integrate Devise into my Rails app at myapp/
    Enhanced GPT>

**System administration:**

    You> Su to root and figure out why relayd(8) isn't working as expected OpenBSD 7.3.
    Enhanced GPT>

**Legal assistance (after uploading a document):**

    You> Review the legal implications of this contract.
    Enhanced GPT>

**Architectural design consultation:**

    You> I need a design for a sustainable building in a cold climate.
    Enhanced GPT>

## Security and Privacy

eGPT places a high priority on the security and privacy of your data, employing state-of-the-art encryption, access control, and compliance measures to ensure the confidentiality and integrity of sensitive information.

