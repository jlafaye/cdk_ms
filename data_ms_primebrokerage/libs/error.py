class Singleton(type):
    _instances: dict = {}

    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]


class AssertCollector(metaclass=Singleton):
    def __init__(self):
        self.errors = []

    def do_assert(self, condition: bool, msg: str):
        if not condition:
            self.errors.append(AssertionError(msg))

    def raise_all(self):
        self._raise_all(self.errors)
        self.errors = []

    def _raise_all(self, errors):
        if len(errors) == 1:
            raise errors[0]

        for e in errors:
            try:
                raise e
            except type(e):
                self._raise_all(errors[1:])

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, exc_tb):
        if exc is not None:
            self.errors.append(exc)
        self.raise_all(self.errors)
