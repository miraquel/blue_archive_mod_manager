sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Unwrap the success value or throw the failure error.
  T get data => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>(:final error, :final stackTrace) =>
          Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current),
      };

  /// Map over the success value.
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
        Success<T>(:final data) => Success(transform(data)),
        Failure<T>(:final error, :final stackTrace) =>
          Failure(error, stackTrace),
      };

  /// Fold: handle both cases.
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(Object error, StackTrace? stackTrace) onFailure,
  ) =>
      switch (this) {
        Success<T>(:final data) => onSuccess(data),
        Failure<T>(:final error, :final stackTrace) =>
          onFailure(error, stackTrace),
      };
}

class Success<T> extends Result<T> {
  const Success(this.data);
  @override
  final T data;

  @override
  String toString() => 'Success($data)';
}

class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure($error)';
}
