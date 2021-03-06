// <auto-generated>
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for
// license information.
//
// Code generated by Microsoft (R) AutoRest Code Generator.
// Changes may cause incorrect behavior and will be lost if the code is
// regenerated.
// </auto-generated>

namespace Microsoft.Azure.TimeSeriesInsights.Models
{
    using Newtonsoft.Json;
    using System.Linq;

    /// <summary>
    /// Variables are named calculations over values from the events. Time
    /// Series Insights variable definitions contain formula and computation
    /// rules. Variables are stored in the type definition in Time Series Model
    /// and can be provided inline via Query APIs to override the stored
    /// definition.
    /// </summary>
    public partial class InlineVariable
    {
        /// <summary>
        /// Initializes a new instance of the Variable class.
        /// </summary>
        public InlineVariable()
        {
            CustomInit();
        }

        /// <summary>
        /// Initializes a new instance of the Variable class.
        /// </summary>
        /// <param name="filter">Filter over the events that restricts the
        /// number of events being considered for computation. Example:
        /// "$event.Status.String='Good'". Optional.</param>
        public InlineVariable(string kind, Tsx value, Tsx aggregation, Tsx filter = default(Tsx))
        {
            Kind = kind;
            Value = value;
            Aggregation = aggregation;
            Filter = filter;
            CustomInit();
        }

        /// <summary>
        /// An initialization method that performs custom operations like setting defaults
        /// </summary>
        partial void CustomInit();

        /// <summary>
        /// Gets or sets kind for the inline variable
        /// it can be numeric, categorical, aggregate, etc.
        /// </summary>
        [JsonProperty(PropertyName = "kind")]
        public string Kind { get; set; }

        /// <summary>
        /// Gets or sets filter over the events that restricts the number of
        /// events being considered for computation. Example:
        /// "$event.Status.String='Good'". Optional.
        /// </summary>
        [JsonProperty(PropertyName = "filter")]
        public Tsx Filter { get; set; }

        /// <summary>
        /// Gets or sets value to apply the aggregation to. Example:
        /// "$event.RandomSignedInt32.Long"
        /// </summary>
        [JsonProperty(PropertyName = "value")]
        public Tsx Value { get; set; }

        /// <summary>
        /// Gets or sets the aggregation formula to apply to the specified value. Example:
        /// "avg($value)"
        /// </summary>
        [JsonProperty(PropertyName = "aggregation")]
        public Tsx Aggregation { get; set; }

        /// <summary>
        /// Validate the object.
        /// </summary>
        /// <exception cref="Rest.ValidationException">
        /// Thrown if validation fails
        /// </exception>
        public virtual void Validate()
        {
            if (Filter != null)
            {
                Filter.Validate();
            }

            if (Value != null)
            {
                Value.Validate();
            }

            if (Aggregation != null)
            {
                Aggregation.Validate();
            }
        }
    }
}
