INFO:     173.42.51.33:0 - "GET /api/v1/health HTTP/1.1" 200 OK
INFO:     10.233.22.250:55152 - "GET /health HTTP/1.1" 200 OK
INFO:     10.233.22.250:55156 - "GET /health HTTP/1.1" 200 OK
INFO:     173.42.51.33:0 - "GET /api/v1/receivables/customers?limit=200 HTTP/1.1" 500 Internal Server Error
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1967, in _exec_single_context
    self.dialect.do_execute(
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/default.py", line 952, in do_execute
    cursor.execute(statement, parameters)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/psycopg/cursor.py", line 117, in execute
    raise ex.with_traceback(None)
psycopg.errors.GroupingError: column "users_1.phone_number" must appear in the GROUP BY clause or be used in an aggregate function
LINE 1: ...es.outstanding_amount), $1) AS total_outstanding, users_1.ph...
                                                             ^
The above exception was the direct cause of the following exception:
Traceback (most recent call last):
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/uvicorn/protocols/http/httptools_impl.py", line 421, in run_asgi
    result = await app(  # type: ignore[func-returns-value]
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/uvicorn/middleware/proxy_headers.py", line 56, in __call__
    return await self.app(scope, receive, send)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/applications.py", line 1159, in __call__
    await super().__call__(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/applications.py", line 90, in __call__
    await self.middleware_stack(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/errors.py", line 186, in __call__
    raise exc
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/errors.py", line 164, in __call__
    await self.app(scope, receive, _send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/cors.py", line 88, in __call__
    await self.app(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/exceptions.py", line 63, in __call__
    await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
    raise exc
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
    await app(scope, receive, sender)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/middleware/asyncexitstack.py", line 18, in __call__
    await self.app(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/routing.py", line 660, in __call__
    await self.middleware_stack(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/routing.py", line 680, in app
    await route.handle(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/routing.py", line 276, in handle
    await self.app(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 134, in app
    await wrap_app_handling_exceptions(app, request)(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
    raise exc
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
    await app(scope, receive, sender)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 120, in app
    response = await f(request)
               ^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 674, in app
    raw_response = await run_endpoint_function(
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 330, in run_endpoint_function
    return await run_in_threadpool(dependant.call, **values)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/concurrency.py", line 32, in run_in_threadpool
    return await anyio.to_thread.run_sync(func)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/anyio/to_thread.py", line 63, in run_sync
    return await get_async_backend().run_sync_in_worker_thread(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 2518, in run_sync_in_worker_thread
    return await future
           ^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 1002, in run
    result = context.run(func, *args)
             ^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/backend/app/api/v1/receivables.py", line 64, in list_customers
    customers = service.list_customers_for_user(user_id=current_user.id, limit=limit)
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/backend/app/services/receivables_service.py", line 120, in list_customers_for_user
    rows = self.db.execute(
           ^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/orm/session.py", line 2351, in execute
    return self._execute_internal(
           ^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/orm/session.py", line 2249, in _execute_internal
    result: Result[Any] = compile_state_cls.orm_execute_statement(
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/orm/context.py", line 306, in orm_execute_statement
    result = conn.execute(
             ^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1419, in execute
    return meth(
           ^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/sql/elements.py", line 527, in _execute_on_connection
    return connection._execute_clauseelement(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1641, in _execute_clauseelement
    ret = self._execute_context(
          ^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1846, in _execute_context
    return self._exec_single_context(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1986, in _exec_single_context
    self._handle_dbapi_exception(
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 2363, in _handle_dbapi_exception
    raise sqlalchemy_exception.with_traceback(exc_info[2]) from e
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1967, in _exec_single_context
    self.dialect.do_execute(
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/default.py", line 952, in do_execute
    cursor.execute(statement, parameters)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/psycopg/cursor.py", line 117, in execute
    raise ex.with_traceback(None)
sqlalchemy.exc.ProgrammingError: (psycopg.errors.GroupingError) column "users_1.phone_number" must appear in the GROUP BY clause or be used in an aggregate function
LINE 1: ...es.outstanding_amount), $1) AS total_outstanding, users_1.ph...
                                                             ^
[SQL: SELECT customers.store_id, customers.name, customers.phone_number, customers.whatsapp_number, customers.email, customers.address, customers.notes, customers.preferred_contact_channel, customers.is_active, customers.id, customers.created_at, customers.source_device_id, customers.local_operation_id, coalesce(sum(receivables.outstanding_amount), %(coalesce_1)s) AS total_outstanding, users_1.phone_number AS phone_number_1, users_1.pin_hash, users_1.role, users_1.is_active AS is_active_1, users_1.full_name, users_1.email AS email_1, users_1.last_login_at, users_1.merchant_id, users_1.id AS id_1, users_1.created_at AS created_at_1, merchants_1.business_name, merchants_1.business_type, merchants_1.owner_user_id, merchants_1.phone, merchants_1.whatsapp_number AS whatsapp_number_1, merchants_1.email AS email_2, merchants_1.address AS address_1, merchants_1.city, merchants_1.region, merchants_1.country, merchants_1.currency_code, merchants_1.id AS id_2, merchants_1.created_at AS created_at_2, stores_1.merchant_id AS merchant_id_1, stores_1.name AS name_1, stores_1.location, stores_1.timezone, stores_1.is_default, stores_1.id AS id_3, stores_1.created_at AS created_at_3 
FROM customers LEFT OUTER JOIN receivables ON receivables.customer_id = customers.id LEFT OUTER JOIN stores AS stores_1 ON stores_1.id = customers.store_id LEFT OUTER JOIN merchants AS merchants_1 ON merchants_1.id = stores_1.merchant_id LEFT OUTER JOIN users AS users_1 ON users_1.id = merchants_1.owner_user_id 
WHERE customers.store_id = %(store_id_1)s::UUID GROUP BY customers.id ORDER BY customers.name ASC 
 LIMIT %(param_1)s::INTEGER]
[parameters: {'coalesce_1': Decimal('0.00'), 'store_id_1': UUID('a8b3f010-90e5-4c95-9a8f-7a60ef92f4d9'), 'param_1': 200}]
(Background on this error at: https://sqlalche.me/e/20/f405)
INFO:     173.42.51.33:0 - "GET /api/v1/health HTTP/1.1" 200 OK
INFO:     173.42.51.33:0 - "GET /api/v1/receivables/customers?limit=200 HTTP/1.1" 500 Internal Server Error
ERROR:    Exception in ASGI application
Traceback (most recent call last):
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1967, in _exec_single_context
    self.dialect.do_execute(
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/default.py", line 952, in do_execute
    cursor.execute(statement, parameters)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/psycopg/cursor.py", line 117, in execute
    raise ex.with_traceback(None)
psycopg.errors.GroupingError: column "users_1.phone_number" must appear in the GROUP BY clause or be used in an aggregate function
LINE 1: ...es.outstanding_amount), $1) AS total_outstanding, users_1.ph...
                                                             ^
The above exception was the direct cause of the following exception:
Traceback (most recent call last):
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/uvicorn/protocols/http/httptools_impl.py", line 421, in run_asgi
    result = await app(  # type: ignore[func-returns-value]
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/uvicorn/middleware/proxy_headers.py", line 56, in __call__
    return await self.app(scope, receive, send)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/applications.py", line 1159, in __call__
    await super().__call__(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/applications.py", line 90, in __call__
    await self.middleware_stack(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/errors.py", line 186, in __call__
    raise exc
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/errors.py", line 164, in __call__
    await self.app(scope, receive, _send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/cors.py", line 88, in __call__
    await self.app(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/middleware/exceptions.py", line 63, in __call__
    await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
    raise exc
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
    await app(scope, receive, sender)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/middleware/asyncexitstack.py", line 18, in __call__
    await self.app(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/routing.py", line 660, in __call__
    await self.middleware_stack(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/routing.py", line 680, in app
    await route.handle(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/routing.py", line 276, in handle
    await self.app(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 134, in app
    await wrap_app_handling_exceptions(app, request)(scope, receive, send)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
    raise exc
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
    await app(scope, receive, sender)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 120, in app
    response = await f(request)
               ^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 674, in app
    raw_response = await run_endpoint_function(
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/fastapi/routing.py", line 330, in run_endpoint_function
    return await run_in_threadpool(dependant.call, **values)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/starlette/concurrency.py", line 32, in run_in_threadpool
    return await anyio.to_thread.run_sync(func)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/anyio/to_thread.py", line 63, in run_sync
    return await get_async_backend().run_sync_in_worker_thread(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 2518, in run_sync_in_worker_thread
    return await future
           ^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 1002, in run
    result = context.run(func, *args)
             ^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/backend/app/api/v1/receivables.py", line 64, in list_customers
    customers = service.list_customers_for_user(user_id=current_user.id, limit=limit)
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/backend/app/services/receivables_service.py", line 120, in list_customers_for_user
    rows = self.db.execute(
           ^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/orm/session.py", line 2351, in execute
    return self._execute_internal(
           ^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/orm/session.py", line 2249, in _execute_internal
    result: Result[Any] = compile_state_cls.orm_execute_statement(
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/orm/context.py", line 306, in orm_execute_statement
    result = conn.execute(
             ^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1419, in execute
    return meth(
           ^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/sql/elements.py", line 527, in _execute_on_connection
    return connection._execute_clauseelement(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1641, in _execute_clauseelement
    ret = self._execute_context(
          ^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1846, in _execute_context
    return self._exec_single_context(
           ^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1986, in _exec_single_context
    self._handle_dbapi_exception(
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 2363, in _handle_dbapi_exception
    raise sqlalchemy_exception.with_traceback(exc_info[2]) from e
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1967, in _exec_single_context
    self.dialect.do_execute(
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/sqlalchemy/engine/default.py", line 952, in do_execute
    cursor.execute(statement, parameters)
  File "/opt/render/project/src/.venv/lib/python3.11/site-packages/psycopg/cursor.py", line 117, in execute
    raise ex.with_traceback(None)
sqlalchemy.exc.ProgrammingError: (psycopg.errors.GroupingError) column "users_1.phone_number" must appear in the GROUP BY clause or be used in an aggregate function
LINE 1: ...es.outstanding_amount), $1) AS total_outstanding, users_1.ph...
                                                             ^
[SQL: SELECT customers.store_id, customers.name, customers.phone_number, customers.whatsapp_number, customers.email, customers.address, customers.notes, customers.preferred_contact_channel, customers.is_active, customers.id, customers.created_at, customers.source_device_id, customers.local_operation_id, coalesce(sum(receivables.outstanding_amount), %(coalesce_1)s) AS total_outstanding, users_1.phone_number AS phone_number_1, users_1.pin_hash, users_1.role, users_1.is_active AS is_active_1, users_1.full_name, users_1.email AS email_1, users_1.last_login_at, users_1.merchant_id, users_1.id AS id_1, users_1.created_at AS created_at_1, merchants_1.business_name, merchants_1.business_type, merchants_1.owner_user_id, merchants_1.phone, merchants_1.whatsapp_number AS whatsapp_number_1, merchants_1.email AS email_2, merchants_1.address AS address_1, merchants_1.city, merchants_1.region, merchants_1.country, merchants_1.currency_code, merchants_1.id AS id_2, merchants_1.created_at AS created_at_2, stores_1.merchant_id AS merchant_id_1, stores_1.name AS name_1, stores_1.location, stores_1.timezone, stores_1.is_default, stores_1.id AS id_3, stores_1.created_at AS created_at_3 
FROM customers LEFT OUTER JOIN receivables ON receivables.customer_id = customers.id LEFT OUTER JOIN stores AS stores_1 ON stores_1.id = customers.store_id LEFT OUTER JOIN merchants AS merchants_1 ON merchants_1.id = stores_1.merchant_id LEFT OUTER JOIN users AS users_1 ON users_1.id = merchants_1.owner_user_id 
WHERE customers.store_id = %(store_id_1)s::UUID GROUP BY customers.id ORDER BY customers.name ASC 
 LIMIT %(param_1)s::INTEGER]
[parameters: {'coalesce_1': Decimal('0.00'), 'store_id_1': UUID('a8b3f010-90e5-4c95-9a8f-7a60ef92f4d9'), 'param_1': 200}]
(Background on this error at: https://sqlalche.me/e/20/f405)
INFO:     173.42.51.33:0 - "GET /api/v1/health HTTP/1.1" 200 OK
INFO:     10.233.22.250:55172 - "GET /health HTTP/1.1" 200 OK