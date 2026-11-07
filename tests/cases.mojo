from test_golden import golden_tests
from test_errors import error_tests
from test_brute import brute_tests
from test_generators import generator_tests
from api import api_tests

def main() raises:
    golden_tests()
    error_tests()
    brute_tests()
    generator_tests()
    api_tests()
