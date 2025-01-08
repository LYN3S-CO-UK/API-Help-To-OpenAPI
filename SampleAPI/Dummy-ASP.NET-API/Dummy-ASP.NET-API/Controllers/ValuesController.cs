using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace Dummy_ASP.NET_API.Controllers
{
    [Authorize]
    public class ValuesController : ApiController
    {
        /// <summary>
        /// Gets a list of values.
        /// </summary>
        /// <returns>An IEnumerable of strings.</returns>
        public IEnumerable<string> Get()
        {
            return new string[] { "value1", "value2" };
        }

        /// <summary>
        /// Gets a specific value by ID.
        /// </summary>
        /// <param name="id">The ID of the value to retrieve.</param>
        /// <returns>A string representing the value.</returns>
        public string Get(int id)
        {
            return "value";
        }

        /// <summary>
        /// Posts a new value.
        /// </summary>
        /// <param name="value">The value to post.</param>
        public void Post([FromBody] string value)
        {
        }

        /// <summary>
        /// Updates an existing value by ID.
        /// </summary>
        /// <param name="id">The ID of the value to update.</param>
        /// <param name="value">The new value.</param>
        public void Put(int id, [FromBody] string value)
        {
        }

        /// <summary>
        /// Deletes a value by ID.
        /// </summary>
        /// <param name="id">The ID of the value to delete.</param>
        public void Delete(int id)
        {
        }
    }
}
